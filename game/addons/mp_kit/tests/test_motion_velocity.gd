extends "res://addons/mp_kit/tests/mp_test.gd"

## MpActor.motion_velocity and what it reads: how fast what a node shows moves, for animation, never the network's
## own motion (a proxy's buffer, a correction fading on the owner). The predicted owner is measured over a real
## network in mpkit_lab's arena probes (lag, correct): its velocity stops with its keys while a correction fades.


func test_a_buffered_proxy_moves_as_its_states() -> void:
	var node := Node2D.new()
	var motion := MpProxyMotion.new(node, true)
	motion.adaptive = false
	motion.delay_s = 0.1
	var now := MpNetClock.server_time()
	check(motion.velocity() == Vector3.ZERO, "before any state: still")
	## Walking at 10 px a tenth of a second (100 px/s) up to now: drawn 0.1 s behind, between two moving states.
	for i in 5:
		motion.draw(0.016, now - 0.4 + i * 0.1, Vector3(i * 10, 0, 0), Quaternion.IDENTITY)
	check(motion.velocity().is_equal_approx(Vector3(100, 0, 0)), "the motion between the states it is drawn between (%s)" % motion.velocity())
	## It stopped: states at the same place from 0.3 s ago (a proxy drawn later sees it still at once).
	var stopped := MpProxyMotion.new(node, true)
	stopped.adaptive = false
	stopped.delay_s = 0.1
	for i in 5:
		var x := minf(i, 2) * 10.0
		stopped.draw(0.016, now - 0.4 + i * 0.1, Vector3(x, 0, 0), Quaternion.IDENTITY)
	check(stopped.velocity() == Vector3.ZERO, "stopped in the states it is drawn between: still, not fading out")
	node.free()


func test_a_following_proxy_moves_as_it_chases() -> void:
	var node := Node2D.new()
	var motion := MpProxyMotion.new(node, false)
	var now := MpNetClock.server_time()
	motion.draw(0.016, now - 0.1, Vector3.ZERO, Quaternion.IDENTITY)
	motion.draw(0.016, now, Vector3(100, 0, 0), Quaternion.IDENTITY)
	var v := motion.velocity()
	check(v.x > 0.0 and is_equal_approx(v.x * 0.016, node.position.x), "how far it chased this frame, per second (%s)" % v)
	motion.draw(0.016, now + 0.1, Vector3(900, 0, 0), Quaternion.IDENTITY, 1)
	check(motion.velocity() == Vector3.ZERO, "a teleport is not motion")
	node.free()


func test_the_server_and_solo_move_as_each_tick() -> void:
	var parent := Node2D.new()
	var actor := MpActor.new()
	actor.name = "MpActor"
	actor.smoothing = MpActor.Smoothing.NONE
	parent.add_child(actor)
	tree.root.add_child(parent)
	await tree.physics_frame
	await tree.physics_frame
	check(actor.motion_velocity() == Vector2.ZERO and actor.motion_speed() == 0.0, "standing: still")
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	for i in 3:
		parent.position += Vector2(2.0, 0.0)
		await tree.physics_frame
	var velocity: Variant = actor.motion_velocity()
	check(velocity is Vector2 and (velocity as Vector2).is_equal_approx(Vector2(2.0 / tick, 0)), "each tick's step, per second, a Vector2 in 2D (%s)" % velocity)
	check(is_equal_approx(actor.motion_speed(), 2.0 / tick), "and its speed as one number")
	parent.position.x += 500.0
	actor.snap()
	await tree.physics_frame
	check(actor.motion_speed() == 0.0, "a teleport (snap) is not a step")
	await tree.physics_frame
	check(actor.motion_speed() == 0.0, "and it stands again")
	parent.free()


func test_a_vector3_in_3d() -> void:
	var parent := Node3D.new()
	var actor := MpActor.new()
	actor.name = "MpActor"
	actor.smoothing = MpActor.Smoothing.NONE
	parent.add_child(actor)
	tree.root.add_child(parent)
	await tree.physics_frame
	parent.position += Vector3(0, 0, 1)
	await tree.physics_frame
	var velocity: Variant = actor.motion_velocity()
	check(velocity is Vector3 and (velocity as Vector3).z > 0.0, "in 3D, a Vector3 (%s)" % velocity)
	parent.free()
