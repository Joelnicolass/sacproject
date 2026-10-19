extends Node

## RFC-037 037c checks, headless, on debug/orders/orders_group.tscn. Drives real input events through the viewport:
##   1. wheel over the circle zooms the map and not the camera; wheel on the world (and on the square's corner) zooms the camera
##   2. M hides and shows the minimap
##   3. a left click with nothing armed does nothing; a right click orders the selected group to a point ahead of the wizard
##      and, after `wait_s`, the group's center is within `max_error_m` of the point
## Prints MINIMAP_INPUT lines and ends with MINIMAP_INPUT PASS / FAIL (exit code 0 / 1).

@export var world: Node
@export var wait_s := 9.0
@export var max_error_m := 6.0
@export var ahead_m := 30.0

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail := "") -> void:
	print("MINIMAP_INPUT %s %s %s" % ["ok" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1


func _button(index: int, pressed: bool, screen: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = screen
	event.global_position = screen
	Input.parse_input_event(event)


func _click(index: int, screen: Vector2) -> void:
	_button(index, true, screen)
	await get_tree().process_frame
	_button(index, false, screen)
	await get_tree().process_frame


func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var minimap: Minimap = world.get_node("%Minimap")
	var camera: Camera3D = world.get_node("%Camera")
	var selection: Node = world.get_node("%Selection")
	var wizard: Node3D = world.call("local_wizard")
	_check("minimap visible", minimap.is_visible_in_tree())
	var xform := minimap.get_global_transform()
	var center := xform * (Vector2.ONE * minimap.radius())
	var corner := xform * Vector2(2.0, 2.0)

	# Wheel.
	var zoom_before := minimap.zoom
	var cam_before := float(camera.get("target_zoom"))
	await _click(MOUSE_BUTTON_WHEEL_UP, center)
	_check("wheel over circle zooms the minimap", minimap.zoom < zoom_before, "%.3f -> %.3f" % [zoom_before, minimap.zoom])
	_check("wheel over circle leaves the camera", is_equal_approx(float(camera.get("target_zoom")), cam_before), "%.4f" % float(camera.get("target_zoom")))
	await _click(MOUSE_BUTTON_WHEEL_UP, corner)
	_check("wheel on the square's corner reaches the camera", not is_equal_approx(float(camera.get("target_zoom")), cam_before))
	var minimap_zoom_mid := minimap.zoom
	cam_before = float(camera.get("target_zoom"))
	await _click(MOUSE_BUTTON_WHEEL_UP, Vector2(200.0, 200.0))
	_check("wheel on the world zooms the camera", not is_equal_approx(float(camera.get("target_zoom")), cam_before))
	_check("wheel on the world leaves the minimap", is_equal_approx(minimap.zoom, minimap_zoom_mid))

	# M toggles.
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.physical_keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check("M hides", not minimap.visible)
	key = key.duplicate()
	Input.parse_input_event(key)
	await get_tree().process_frame
	_check("M shows again", minimap.visible)
	await get_tree().process_frame

	# The camera settles after its zoom (the map's center is ahead of the wizard by the camera distance).
	await get_tree().create_timer(3.0).timeout

	# Selection through the test bed's own action, then the clicks.
	var press := InputEventAction.new()
	press.action = &"check_tick"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var units: Array = selection.call("units")
	_check("group selected", units.size() >= 2, str(units.size()))
	var forward: Vector3 = wizard.call("facing_flat")
	var target_xz := Vector2(wizard.global_position.x + forward.x * ahead_m, wizard.global_position.z + forward.z * ahead_m)
	var local := minimap.world_to_minimap(Vector3(target_xz.x, 0.0, target_xz.y))
	_check("target is inside the circle", local.distance_to(Vector2.ONE * minimap.radius()) < minimap.radius() - 4.0, str(local))
	var before := _center(units)
	await get_tree().process_frame
	target_xz = minimap.local_to_world(local)
	await _click(MOUSE_BUTTON_LEFT, xform * local)
	await get_tree().create_timer(1.0).timeout
	_check("left click with nothing armed does nothing", _center(units).distance_to(before) < 0.5 and selection.call("units").size() == units.size())
	await _click(MOUSE_BUTTON_RIGHT, xform * local)
	var ping: Node3D = world.get_node("%Ping")
	print("MINIMAP_INPUT target %s ping %s" % [target_xz, ping.global_position])
	for second in int(wait_s):
		await get_tree().create_timer(1.0).timeout
		print("MINIMAP_INPUT t=%d error %.2f" % [second + 1, _center(units).distance_to(target_xz)])
	var error := _center(units).distance_to(target_xz)
	_check("ordered group arrives", error <= max_error_m, "error %.2f m (max %.1f)" % [error, max_error_m])
	print("MINIMAP_INPUT %s" % ("PASS" if _fails == 0 else "FAIL"))
	get_tree().quit(0 if _fails == 0 else 1)


func _center(units: Array) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for unit in units:
		if is_instance_valid(unit):
			sum += Vector2(unit.global_position.x, unit.global_position.z)
			count += 1
	return sum / maxf(float(count), 1.0)
