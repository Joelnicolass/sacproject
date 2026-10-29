extends "res://addons/rts_kit/tests/rts_test.gd"

## The two examples played end to end, headless, through the same events a player makes: a box of
## mouse events selects the own units, a right tap on the ground orders them, they walk to their
## slots and report `complete()`; a group key and Alt+N work on the real rig.

const SCENE_3D := preload("res://addons/rts_kit/examples/skirmish_3d/skirmish_3d.tscn")
const SCENE_2D := preload("res://addons/rts_kit/examples/skirmish_2d/skirmish_2d.tscn")


func _own(selection: RtsSelection) -> Array[RtsUnit]:
	var result: Array[RtsUnit] = []
	for unit in RtsUnit.all(tree):
		if selection.can_select(unit):
			result.append(unit)
	return result


func _screen(unit: RtsUnit) -> Vector2:
	return RtsSpace.screen_of(root.get_viewport(), unit.center_point(), unit.is_2d())


func _play(scene: PackedScene, ground_screen: Vector2) -> void:
	var example := scene.instantiate()
	root.add_child(example)
	await physics(3)
	var command: RtsCommandInput = example.get_node("Command")
	var selection := command.selection
	var own := _own(selection)
	check(own.size() == 12, "%s: twelve own units to select" % example.name)
	# A box around every own unit, as mouse events on the world view.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for unit in own:
		var at := _screen(unit)
		low = low.min(at)
		high = high.max(at)
	low -= Vector2(30, 30)
	high += Vector2(30, 30)
	var view: Control = example.get_node("Hud/View")
	view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, true, low))
	view.gui_input.emit(_motion(high))
	view.gui_input.emit(_button(MOUSE_BUTTON_LEFT, false, high))
	check(selection.size() == 12, "%s: the box selected them all (%d)" % [example.name, selection.size()])
	check(not selection.units().any(func(u: RtsUnit) -> bool: return u.has_tag(&"anchor")), "%s: never the hero (not selectable)" % example.name)
	var done: Array = []
	for unit in own:
		unit.order_ended.connect(func(_o: RtsUnitOrder, result: StringName) -> void: done.append(result))
	view.gui_input.emit(_button(MOUSE_BUTTON_RIGHT, true, ground_screen))
	view.gui_input.emit(_button(MOUSE_BUTTON_RIGHT, false, ground_screen))
	var orders_given := own.filter(func(u: RtsUnit) -> bool: return u.current_order() != null).size()
	check(orders_given == 12, "%s: a right tap on the ground ordered all twelve" % example.name)
	var spots := {}
	for unit in own:
		spots[unit] = unit.current_order().spot()
	for i in 600:
		await tree.physics_frame
		if done.size() >= 12:
			break
	check(done.size() == 12 and done.all(func(r: StringName) -> bool: return r == &"done"), "%s: every unit walked to its slot and completed (%d)" % [example.name, done.size()])
	var placed := true
	for unit in own:
		var spot: Vector3 = spots[unit]
		placed = placed and Vector2(unit.position().x - spot.x, unit.position().z - spot.z).length() < 1.0
	check(placed, "%s: each stands on its own slot" % example.name)
	# Ctrl/Cmd+1 stores the group; 1 recalls it after a clear.
	var store := InputEventKey.new()
	store.physical_keycode = KEY_1
	store.command_or_control_autoremap = true
	store.pressed = true
	command._input(store)
	selection.clear()
	var recall := InputEventKey.new()
	recall.physical_keycode = KEY_1
	recall.pressed = true
	command._input(recall)
	check(selection.size() == 12, "%s: Ctrl/Cmd+1 then 1 brings the group back" % example.name)
	var alt := InputEventKey.new()
	alt.physical_keycode = KEY_7
	alt.alt_pressed = true
	alt.pressed = true
	command._input(alt)
	check(own.all(func(u: RtsUnit) -> bool: return u.formation == &"wedge"), "%s: Alt+7 keeps the wedge on them" % example.name)
	example.queue_free()
	await tree.process_frame


func test_skirmish_3d() -> void:
	var camera_point := Vector2(640, 260)
	await _play(SCENE_3D, camera_point)


func test_skirmish_2d() -> void:
	await _play(SCENE_2D, Vector2(640, 200))


func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	return event


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event
