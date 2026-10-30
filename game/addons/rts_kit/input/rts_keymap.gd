class_name RtsKeymap
extends RefCounted

## The kit's InputMap actions and their default bindings. `install()` adds every action the project
## does not have yet and never touches one it has: a game rebinds by defining the action itself
## (Project Settings > Input Map) or at runtime through InputMap. Letters and digits are physical
## keys (the same place on any keyboard layout).
##
## | Action | Default |
## |---|---|
## | rts_select / rts_order | left / right mouse button |
## | rts_order_menu | Tab (hold: the radial menu at the pointer) |
## | rts_order_attack / rts_order_guard / rts_order_move | A / G / M (arm the icon) |
## | rts_order_retreat | R |
## | rts_formation_1..8 | Alt+1..8 |
## | rts_group_1..0 | 1..0 (Shift adds) |
## | rts_group_set_1..0 | Ctrl+1..0 (Cmd on macOS with `command_on_macos`) |
## | rts_camera_pan_left / right / up / down | arrow keys |
## | rts_camera_turn_left / right | Q / E |
## | rts_camera_zoom_in / out | Page Up / Page Down |
## | rts_camera_wheel_in / out | mouse wheel up / down |
## | rts_camera_orbit | middle mouse button (follow: look around; free: drag the map) |
## | rts_camera_orbit_modifier | Alt (Alt + left drag = middle drag) |

const GROUP_KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]


## Adds the kit's actions the project lacks. `command_on_macos`: the group-set keys use Cmd on macOS
## and Ctrl elsewhere; false: Ctrl everywhere.
static func install(command_on_macos := true) -> void:
	var defaults := bindings(command_on_macos)
	for action: StringName in defaults:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		for event: InputEvent in defaults[action]:
			InputMap.action_add_event(action, event)


## The default bindings: action -> Array[InputEvent].
static func bindings(command_on_macos := true) -> Dictionary:
	var map := {}
	map[&"rts_select"] = [_mouse(MOUSE_BUTTON_LEFT)]
	map[&"rts_order"] = [_mouse(MOUSE_BUTTON_RIGHT)]
	map[&"rts_order_menu"] = [_key(KEY_TAB)]
	map[&"rts_order_attack"] = [_key(KEY_A)]
	map[&"rts_order_guard"] = [_key(KEY_G)]
	map[&"rts_order_move"] = [_key(KEY_M)]
	map[&"rts_order_retreat"] = [_key(KEY_R)]
	for i in 8:
		var formation := _key((KEY_1 + i) as Key)
		formation.alt_pressed = true
		map[StringName("rts_formation_%d" % (i + 1))] = [formation]
	for i in GROUP_KEYS.size():
		var code: Key = KEY_0 if i == 9 else (KEY_1 + i) as Key
		map[StringName("rts_group_" + GROUP_KEYS[i])] = [_key(code)]
		var store := _key(code)
		if command_on_macos:
			store.command_or_control_autoremap = true
		else:
			store.ctrl_pressed = true
		map[StringName("rts_group_set_" + GROUP_KEYS[i])] = [store]
	map[&"rts_camera_pan_left"] = [_key(KEY_LEFT)]
	map[&"rts_camera_pan_right"] = [_key(KEY_RIGHT)]
	map[&"rts_camera_pan_up"] = [_key(KEY_UP)]
	map[&"rts_camera_pan_down"] = [_key(KEY_DOWN)]
	map[&"rts_camera_turn_left"] = [_key(KEY_Q)]
	map[&"rts_camera_turn_right"] = [_key(KEY_E)]
	map[&"rts_camera_zoom_in"] = [_key(KEY_PAGEUP)]
	map[&"rts_camera_zoom_out"] = [_key(KEY_PAGEDOWN)]
	map[&"rts_camera_wheel_in"] = [_mouse(MOUSE_BUTTON_WHEEL_UP)]
	map[&"rts_camera_wheel_out"] = [_mouse(MOUSE_BUTTON_WHEEL_DOWN)]
	map[&"rts_camera_orbit"] = [_mouse(MOUSE_BUTTON_MIDDLE)]
	map[&"rts_camera_orbit_modifier"] = [_key(KEY_ALT)]
	return map


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
