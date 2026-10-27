extends "res://addons/mp_kit/tests/mp_test.gd"

## MpCorrectionSmoother: a correction of the owner is drawn fading out, while the node's real pose (physics) is
## already the corrected one; a teleport is drawn at once; what the game writes itself always wins.


## A 2D node corrected from `from` to `to` in a physics tick, as MpActor leaves it (absorbed, tick marked).
func _corrected_2d(from: Vector2, to: Vector2, time_s := 0.1, snap := 0.0) -> Array:
	var node := Node2D.new()
	node.position = to
	var smoother := MpCorrectionSmoother.new(node)
	smoother.time_s = time_s
	smoother.snap_distance = snap
	smoother.absorb(Vector3(from.x, from.y, 0.0), Quaternion.IDENTITY)
	smoother.mark_tick()
	return [node, smoother]


## One physics tick that does not move the node: the real pose back, then the tick marked.
func _tick(smoother: MpCorrectionSmoother) -> void:
	smoother.restore()
	smoother.mark_tick()


func test_a_correction_is_drawn_where_it_was_then_fades() -> void:
	var made := _corrected_2d(Vector2.ZERO, Vector2(40, 0))
	var node: Node2D = made[0]
	var smoother: MpCorrectionSmoother = made[1]
	smoother.draw(0.0)
	check(node.position.is_equal_approx(Vector2.ZERO), "the frame of the correction is drawn where the node was: %s" % node.position)
	smoother.restore()
	check(node.position.is_equal_approx(Vector2(40, 0)), "before physics the node is back at its real pose")
	smoother.mark_tick()
	var steps: Array[float] = []
	var last := 0.0
	for i in 12:
		smoother.draw(1.0 / 60.0)
		steps.append(node.position.x - last)
		last = node.position.x
		_tick(smoother)
	check(steps.max() < 10.0, "no frame jumps much (largest %.1f of 40)" % steps.max())
	check(absf(last - 40.0 * (1.0 - exp(-0.2 / 0.1))) < 0.5, "after 0.2 s it went the share an exponential of 0.1 s goes: %.1f" % last)
	for i in 120:
		smoother.draw(1.0 / 60.0)
		_tick(smoother)
	check(smoother.offset() == 0.0, "after 2 s the offset is gone")
	smoother.draw(1.0 / 60.0)
	check(node.position == Vector2(40, 0), "with nothing left it draws the real pose")
	node.free()


func test_several_frames_between_ticks_fade_from_the_same_real_pose() -> void:
	var made := _corrected_2d(Vector2.ZERO, Vector2(40, 0))
	var node: Node2D = made[0]
	var smoother: MpCorrectionSmoother = made[1]
	smoother.draw(1.0 / 120.0)
	var first := node.position.x
	smoother.draw(1.0 / 120.0)
	check(node.position.x > first and node.position.x < 40.0, "a second frame before the next tick keeps fading toward the real pose")
	smoother.restore()
	check(node.position == Vector2(40, 0), "and physics still gets the real pose")
	node.free()


func test_corrections_add_up_and_clear_drops_them() -> void:
	var made := _corrected_2d(Vector2.ZERO, Vector2(10, 0))
	var node: Node2D = made[0]
	var smoother: MpCorrectionSmoother = made[1]
	node.position = Vector2(30, 0) # it walked
	smoother.absorb(Vector3(30, 0, 0), Quaternion.IDENTITY) # a correction of 0
	smoother.mark_tick()
	check(is_equal_approx(smoother.offset(), 10.0), "a correction of 0 keeps what was still fading")
	smoother.draw(0.0)
	smoother.clear()
	check(smoother.offset() == 0.0 and node.position == Vector2(30, 0), "clear: drawn at the real pose at once")
	node.free()


func test_a_long_correction_a_teleport_or_zero_time_is_drawn_at_once() -> void:
	var made := _corrected_2d(Vector2.ZERO, Vector2(500, 0), 0.1, 100.0)
	check(made[1].offset() == 0.0, "past snap_distance (a teleport): no fade")
	made[0].free()
	made = _corrected_2d(Vector2.ZERO, Vector2(40, 0), 0.0)
	check(made[1].offset() == 0.0, "time_s 0: corrections are drawn at once")
	made[0].free()
	made = _corrected_2d(Vector2.ZERO, Vector2(40, 0))
	var smoother: MpCorrectionSmoother = made[1]
	smoother.jump_next()
	smoother.absorb(Vector3(-200, 0, 0), Quaternion.IDENTITY)
	check(smoother.offset() == 0.0, "jump_next: the next correction (a teleport announced first) is drawn at once, and what was fading goes too")
	made[0].free()


func test_what_the_game_writes_wins() -> void:
	var made := _corrected_2d(Vector2.ZERO, Vector2(40, 0))
	var node: Node2D = made[0]
	var smoother: MpCorrectionSmoother = made[1]
	smoother.draw(1.0 / 60.0)
	node.position = Vector2(100, 100) # the game places it this frame
	smoother.draw(1.0 / 60.0)
	check(node.position == Vector2(100, 100), "a pose the game wrote is not overwritten")
	smoother.restore()
	check(node.position == Vector2(100, 100) and smoother.offset() == 0.0, "nor undone before physics, and nothing is left to fade")
	node.free()
	## A rotation the game sets every frame (an aim) while a position correction fades: the aim stays.
	var turned := Node2D.new()
	turned.position = Vector2(40, 0)
	turned.rotation = 0.5
	var smoother2 := MpCorrectionSmoother.new(turned)
	smoother2.absorb(Vector3.ZERO, Quaternion(Vector3.BACK, 0.2))
	smoother2.mark_tick()
	turned.rotation = 1.2 # the game aims after the tick
	smoother2.draw(1.0 / 60.0)
	check(is_equal_approx(turned.rotation, 1.2), "the game's aim is drawn as it set it: %.2f" % turned.rotation)
	check(turned.position.x < 40.0, "while the position correction still fades")
	smoother2.restore()
	check(is_equal_approx(turned.rotation, 1.2) and turned.position == Vector2(40, 0), "before physics: the real position, the game's aim")
	turned.free()


func test_rotation_fades_in_3d() -> void:
	var node := Node3D.new()
	node.position = Vector3(0, 0, 2)
	node.quaternion = Quaternion(Vector3.UP, PI / 2.0)
	var smoother := MpCorrectionSmoother.new(node)
	smoother.absorb(Vector3.ZERO, Quaternion.IDENTITY)
	smoother.mark_tick()
	smoother.draw(0.0)
	check(node.position.is_equal_approx(Vector3.ZERO) and node.quaternion.is_equal_approx(Quaternion.IDENTITY),
		"3D: drawn at the old position and rotation")
	smoother.restore()
	check(node.quaternion.is_equal_approx(Quaternion(Vector3.UP, PI / 2.0)), "the real rotation is the corrected one")
	smoother.mark_tick()
	for i in 120:
		smoother.draw(1.0 / 60.0)
	check(node.quaternion.is_equal_approx(Quaternion(Vector3.UP, PI / 2.0)) and node.position.is_equal_approx(Vector3(0, 0, 2)),
		"after 2 s drawn at the real pose")
	node.free()
