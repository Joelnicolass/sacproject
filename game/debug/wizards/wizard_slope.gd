extends Node

## F88 round 4 case (headless): the local wizard stands at the foot of the ridge east of the tipis of High Noon (about 48°,
## the slope where the creatures of crowd_rock stopped) and the player holds W (move_forward) toward `heading`. Every
## physics tick the case reads the wizard. PASS: it gets `climb_m` along the heading and gains `rise_m` of height within
## `limit_s`, and is never still (< 1 cm in a tick) for more than `still_s` while W is held. One line
## `wizard_slope: PASS|FAIL {…}`; with quit_when_done it quits. Run: Godot --headless --fixed-fps 60 --path game
## res://debug/wizards/wizard_slope.tscn

@export var world: Node
## The world camera: it writes its yaw into the wizard's look_yaw every frame, so the heading is set here.
@export var camera: Node
@export var start := Vector3(1566.0, 0.0, 1495.0)
## Yaw of the heading (REST_FACING (0, 0, 1) turned about Y): PI/2 = +x, up the ridge.
@export var heading_yaw := PI * 0.5
@export var climb_m := 22.0
@export var rise_m := 8.0
@export var limit_s := 8.0
@export var still_s := 0.5
@export var quit_when_done := true

var _started := false


func _get_configuration_warnings() -> PackedStringArray:
	if world == null or camera == null:
		return PackedStringArray(["Asigná world y camera."])
	return PackedStringArray()


func _physics_process(_delta: float) -> void:
	if _started or world.call("local_wizard") == null:
		return
	_started = true
	_run.call_deferred(world.call("local_wizard"))


func _run(wizard: CharacterBody3D) -> void:
	var tree := get_tree()
	for _i in 30:
		await tree.physics_frame
	var ground := float(FallCheck.terrain_of(wizard).call("ground_height", start.x, start.z))
	wizard.global_position = Vector3(start.x, ground + 0.1, start.z)
	wizard.velocity = Vector3.ZERO
	## The camera's yaw and the wizard's facing need not share a zero: turn the camera until facing_flat is the heading.
	var want := Vector3(sin(heading_yaw), 0.0, cos(heading_yaw))
	var yaw := heading_yaw
	for _turn in 3:
		camera.set("yaw", yaw)
		for _i in 10:
			await tree.physics_frame
		var facing: Vector3 = wizard.call("facing_flat")
		yaw += atan2(want.x, want.z) - atan2(facing.x, facing.z)
	var from := wizard.global_position
	var ahead: Vector3 = wizard.call("facing_flat")
	Input.action_press("move_forward")
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var ticks := 0
	var still := 0
	var worst := 0
	var last := wizard.global_position
	var climbed := 0.0
	while ticks < int(limit_s / dt):
		## Headless, the pointer sits on a screen edge and the camera's edge steering would turn the wizard: hold the yaw.
		camera.set("yaw", yaw)
		await tree.physics_frame
		ticks += 1
		var here := wizard.global_position
		if Vector2(here.x - last.x, here.z - last.z).length() < 0.01:
			still += 1
			worst = maxi(worst, still)
		else:
			still = 0
		last = here
		climbed = (here - from).dot(ahead)
		if climbed >= climb_m:
			break
	var pressed := Input.is_action_pressed("move_forward", true)
	var end_facing: Vector3 = wizard.call("facing_flat")
	Input.action_release("move_forward")
	var rise := wizard.global_position.y - from.y
	var ok := climbed >= climb_m and rise >= rise_m and worst * dt <= still_s
	var report := {"climbed_m": snappedf(climbed, 0.01), "rise_m": snappedf(rise, 0.01), "seconds": snappedf(ticks * dt, 0.01),
			"worst_still_s": snappedf(worst * dt, 0.01), "at": [snappedf(wizard.global_position.x, 0.1), snappedf(wizard.global_position.z, 0.1)],
			"on_wall": wizard.is_on_wall(), "heading": [snappedf(ahead.x, 0.01), snappedf(ahead.z, 0.01)], "from": [snappedf(from.x, 0.1), snappedf(from.z, 0.1)], "pressed": pressed, "end_facing": [snappedf(end_facing.x, 0.01), snappedf(end_facing.z, 0.01)], "velocity": str(wizard.velocity)}
	print("wizard_slope: %s %s" % ["PASS" if ok else "FAIL", JSON.stringify(report)])
	if quit_when_done:
		tree.quit(0 if ok else 1)
