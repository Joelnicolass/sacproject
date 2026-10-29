extends "res://addons/rts_kit/tests/rts_test.gd"

## RtsCamera3D (follow and free) and RtsCamera2D: placement, the ground, the limits of the look, the
## drag threshold, the wheel blockers, the edges, the pan, the bounds and the shared yaw contract.


func _camera_3d(mode: RtsCamera3D.Mode) -> RtsCamera3D:
	RtsKeymap.install()
	var camera := RtsCamera3D.new()
	camera.mode = mode
	root.add_child(camera)
	camera.current = true
	return camera


func _follow(camera: RtsCamera3D, at := Vector3.ZERO) -> Node3D:
	var body := Node3D.new()
	root.add_child(body)
	body.global_position = at
	camera.set_follow(body)
	return body


func test_follow_placement() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera._place()
	# h 1.5: distance max(0.6 + 2.32·1.5, 4.5) = 4.5 · (0.6 + 3.13·0.125); height (1.75·1.5 - 1.15) ·
	# (0.6 + 2.8·0.125); the eye one meter above that, behind the body (yaw 0 faces +Z).
	var distance := 4.5 * (0.6 + 3.13 * 0.125)
	var height := (1.75 * 1.5 - 1.15) * (0.6 + 2.8 * 0.125)
	check(near(camera.global_position, Vector3(0, height + 1.0, -distance), 0.0005), "the eye: %s" % camera.global_position)
	var focus := (1.75 * 1.5 - 1.15) - 0.3 * 0.5
	check(near(camera.view_pitch_deg, rad_to_deg(atan2(height - focus, distance)), 0.001), "looking down at the focus: %s°" % camera.view_pitch_deg)
	check(near(RtsSpace.yaw_of_direction(-camera.global_basis.z), 0.0, 0.001), "facing the yaw")


func test_follow_keeps_over_the_ground() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.height_at = func(_x: float, _z: float) -> float: return 10.0
	camera._place()
	check(camera.global_position.y >= 10.0 + camera.ground_clearance - 0.0001, "never under live ground: %s" % camera.global_position.y)
	camera.height_at = func(_x: float, _z: float) -> float: return NAN
	camera._place()
	var distance := 4.5 * (0.6 + 3.13 * 0.125)
	check(near(camera.global_position.z, -distance, 0.001) and camera.global_position.y < 5.0, "unknown ground does not lift the eye")


func test_look_limits() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.look_pitch_deg = 500.0
	camera._place()
	check(near(camera.view_pitch_deg, camera.look_down_max_deg), "at most 85° down")
	camera.look_pitch_deg = -500.0
	camera._place()
	check(near(camera.view_pitch_deg, -camera.look_up_max_deg), "at most 80° up")


func test_drag_threshold() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	Input.action_press(&"rts_camera_orbit")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(2, 0)
	var yaw_before := camera.yaw
	camera._on_motion(motion)
	check(not camera.is_dragging(), "2 px: not a drag")
	check(not near(camera.yaw, yaw_before), "free look turned the view")
	camera._on_motion(motion)
	check(camera.is_dragging(), "4 px: a drag (the click that ends it is no order)")
	Input.action_release(&"rts_camera_orbit")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	camera._input(press)
	check(not camera.is_dragging(), "a new press starts over")


func test_wheel_and_its_blockers() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(100, 100)
	var before := camera.target_zoom
	camera._input(wheel)
	check(near(camera.target_zoom, before + camera.wheel_step), "the wheel zooms out")
	var script := GDScript.new()
	script.source_code = "extends Control\nfunc covers(_screen: Vector2) -> bool:\n\treturn true\n"
	script.reload()
	var minimap := Control.new()
	minimap.set_script(script)
	root.add_child(minimap)
	camera.wheel_blockers = [minimap]
	before = camera.target_zoom
	camera._input(wheel)
	check(near(camera.target_zoom, before), "not over a blocker that covers the pointer")


func test_follow_edges_turn_the_view() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	_follow(camera)
	camera.debug_pointer = Vector2(10, 360)
	camera._process(1.0)
	check(near(camera.yaw, deg_to_rad(36.0), 0.001), "the left edge turns 36°/s: %s" % rad_to_deg(camera.yaw))


func test_free_mode_pans_turns_and_stays_in_bounds() -> void:
	var camera := _camera_3d(RtsCamera3D.Mode.FREE)
	camera.bounds = Rect2(-10, -10, 20, 20)
	check(camera.focus(Vector3(50, 0, -50)) and near(camera.free_target, Vector3(10, 0, -10)), "focus, kept in bounds")
	camera.focus(Vector3.ZERO)
	camera._place()
	var look := -camera.global_basis.z
	var to_target := (camera.free_target - camera.global_position).normalized()
	check(near(look, to_target, 0.001), "it looks at its target")
	check(near(camera.view_pitch_deg, camera.free_pitch_deg), "from its pitch")
	Input.action_press(&"rts_camera_pan_right")
	camera._process(0.5)
	Input.action_release(&"rts_camera_pan_right")
	var moved := camera.free_target
	check(moved.dot(RtsSpace.right(camera.yaw)) > 0.5 and absf(moved.dot(RtsSpace.ahead(camera.yaw))) < 0.001, "the pan key moves it to the view's right: %s" % moved)
	Input.action_press(&"rts_camera_turn_left")
	camera._process(0.5)
	Input.action_release(&"rts_camera_turn_left")
	check(near(camera.yaw, deg_to_rad(90.0), 0.001), "the turn key turns it")
	var pointer := RtsPointer.new()
	pointer.dimension = RtsPointer.Dimension.D3
	root.add_child(pointer)
	camera._place()
	check(near(pointer.camera_yaw(), camera.yaw, 0.001), "the pointer reads the same yaw the camera keeps")
	var follow_camera := _camera_3d(RtsCamera3D.Mode.FOLLOW)
	check(not follow_camera.focus(Vector3.ONE), "follow mode ignores focus")


func test_camera_2d() -> void:
	RtsKeymap.install()
	var camera := RtsCamera2D.new()
	root.add_child(camera)
	camera.make_current()
	check(near(camera.yaw, PI), "unturned: formations face up the screen")
	camera.bounds = Rect2(0, 0, 1000, 1000)
	check(camera.focus(Vector3(5000, 0, 300)) and near(camera.global_position, Vector2(1000, 300)), "focus, kept in bounds")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var zoom_before := camera.zoom.x
	camera._input(wheel)
	check(camera.zoom.x > zoom_before, "the wheel zooms in")
	Input.action_press(&"rts_camera_orbit")
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(10, 0)
	var at := camera.global_position
	camera._input(drag)
	Input.action_release(&"rts_camera_orbit")
	check(camera.global_position.x < at.x and camera.is_dragging(), "a middle drag moves the map with the pointer")
	camera.can_turn = true
	camera.ignore_rotation = false
	camera.rotation = PI * 0.5
	var up := Vector2(0, -1).rotated(PI * 0.5)
	check(near(camera.yaw, atan2(up.x, up.y)), "turned: the yaw follows the screen's up")
