extends "res://addons/rts_kit/tests/rts_test.gd"

## The command input on a real 3D scene (ground and unit colliders) and on 2D: the pointer, the
## context -> order map, the armed cycle, the left button, the radial menu, the group and formation
## keys, and a modal UI that blocks it all.

const MENU := preload("res://addons/rts_kit/ui/radial/rts_radial_menu.tscn")

var orders: RtsOrders
var selection: RtsSelection
var pointer: RtsPointer
var armed: RtsArmedCommand
var state: RtsCommandState
var order_input: RtsOrderInput
var select_input: RtsSelectInput
var camera: Camera3D
## Orders that went out (`send` captured), and what the state said.
var sent: Array = []
var said: Array = []


func _rig(flat := false) -> void:
	sent.clear()
	said.clear()
	RtsKeymap.install()
	orders = RtsOrders.new()
	selection = RtsSelection.new()
	pointer = RtsPointer.new()
	pointer.dimension = RtsPointer.Dimension.D2 if flat else RtsPointer.Dimension.D3
	armed = RtsArmedCommand.new()
	state = RtsCommandState.new()
	state.cues = RtsCueSet.new()
	armed.state = state
	order_input = RtsOrderInput.new()
	order_input.selection = selection
	order_input.orders = orders
	order_input.pointer = pointer
	order_input.armed = armed
	order_input.state = state
	select_input = RtsSelectInput.new()
	select_input.selection = selection
	select_input.pointer = pointer
	select_input.armed = armed
	select_input.order_input = order_input
	for node in [orders, selection, pointer, armed, state, order_input, select_input]:
		root.add_child(node)
	orders.send = func(order: RtsOrder) -> void: sent.append(order)
	state.said.connect(func(text: String, cue: StringName) -> void: said.append([text, cue]))
	if flat:
		return
	camera = Camera3D.new()
	root.add_child(camera)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0, 40, 0))
	camera.current = true
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)


func _unit(at: Vector3, slot := 1) -> RtsUnit:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	body.add_child(unit)
	return unit


func _unit_2d(at: Vector2, slot := 1) -> RtsUnit:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	body.add_child(shape)
	root.add_child(body)
	body.global_position = at
	var unit := RtsUnit.new()
	unit.owner_slot = slot
	body.add_child(unit)
	return unit


func _screen(point: Vector3) -> Vector2:
	return camera.unproject_position(point)


func test_pointer_3d() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	var foe := _unit(Vector3(10, 0.5, 0), 2)
	await physics()
	var ground: Variant = pointer.ground_at(_screen(Vector3(-10, 0, 5)))
	check(ground is Vector3 and near(ground, Vector3(-10, 0, 5), 0.05), "the ground point under a pixel: %s" % ground)
	check(pointer.unit_under(_screen(Vector3(0, 0.5, 0))) == mine, "the unit under a pixel")
	check(pointer.body_under(_screen(Vector3(10, 0.5, 0))) == foe.body, "the body under a pixel")
	check(pointer.body_under(_screen(Vector3(-20, 0, -20))) == null and pointer.is_empty_at(_screen(Vector3(-20, 0, -20))), "nothing but ground")
	check(pointer.relation(mine.body) == RtsUnit.OWN and pointer.is_enemy(foe.body), "own and enemy")
	check(pointer.body_under(_screen(Vector3(0, 0.5, 0)), [mine.body]) == null, "a skipped body is seen through")
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.FORWARD), Vector3(0, 40, 0))
	check(pointer.ground_at(Vector2(640, 360)) == null, "the sky has no ground")


func test_pointer_2d() -> void:
	_rig(true)
	var mine := _unit_2d(Vector2(200, 200))
	await physics()
	check(pointer.ground_at(Vector2(50, 60)) == Vector3(50, 0, 60), "2D ground: the canvas point")
	check(pointer.unit_under(Vector2(203, 198)) == mine, "the 2D unit under a pixel")
	check(pointer.body_under(Vector2(400, 400)) == null, "nothing there")
	pointer.ground_bounds_2d = Rect2(0, 0, 100, 100)
	check(pointer.ground_at(Vector2(500, 500)) == null, "outside the map's bounds: no ground")
	check(near(pointer.camera_yaw(), PI), "an unturned 2D view: formations face up the screen")


func test_right_click_by_context() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	var friend := _unit(Vector3(-6, 0.5, 0))
	var foe := _unit(Vector3(10, 0.5, 0), 2)
	await physics()
	selection.select_only([mine])
	order_input.right_at(_screen(Vector3(10, 0.5, 0)))
	check(sent[-1].command == &"attack" and sent[-1].target == foe.body, "an enemy: attack it")
	order_input.right_at(_screen(Vector3(-6, 0.5, 0)))
	check(sent[-1].command == &"guard" and sent[-1].target == friend.body, "own: guard it")
	order_input.right_at(_screen(Vector3(5, 0, 15)))
	check(sent[-1].command == &"move" and sent[-1].target == null and near(sent[-1].point, Vector3(5, 0, 15), 0.05), "the ground: move there")
	order_input.classify = func(body: Node) -> StringName: return &"corpse" if body == friend.body else &""
	order_input.context_orders[&"corpse"] = &"guard_area"
	order_input.point_contexts = [&"corpse"]
	order_input.right_at(_screen(Vector3(-6, 0.5, 0)))
	check(sent[-1].command == &"guard_area" and sent[-1].target == null and near(sent[-1].point, friend.position()), "a game's class: its own order, on the spot")
	check(order_input.context_kind(_screen(Vector3(-6, 0.5, 0))) == &"corpse" and order_input.context_kind(_screen(Vector3(30, 0, 30))) == &"ground", "context_kind")
	selection.clear()
	var before := sent.size()
	order_input.right_at(_screen(Vector3(5, 0, 15)))
	check(sent.size() == before and said[-1][0] == RtsRefusal.NOBODY and said[-1][1] == &"refused", "nothing selected: refused (with the refused cue)")


func test_the_sky_is_refused() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	await physics()
	selection.select_only([mine])
	camera.global_transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.FORWARD), Vector3(0, 40, 0))
	order_input.right_at(Vector2(640, 360))
	check(sent.is_empty() and said[-1][0] == RtsRefusal.NO_GROUND, "an order at the sky")


func test_the_armed_cycle() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	var foe := _unit(Vector3(10, 0.5, 0), 2)
	await physics()
	selection.select_only([mine])
	armed.arm_order(&"attack")
	check(armed.is_armed() and state.armed == &"attack", "attack armed")
	armed.arm_order(&"guard")
	check(state.armed == &"attack", "another icon does not replace it")
	armed.arm_order(&"guard", true)
	check(state.armed == &"guard", "unless it says replace")
	order_input.right_at(_screen(Vector3(5, 0, 5)))
	check(not armed.is_armed() and sent.is_empty(), "a right click cancels what is armed and orders nothing")
	armed.arm_order(&"attack")
	select_input.left_at(_screen(Vector3(10, 0.5, 0)), false, false)
	check(sent[-1].command == &"attack" and sent[-1].target == foe.body and not armed.is_armed(), "the armed attack on a body, then disarmed")
	armed.arm_order(&"attack")
	select_input.left_at(_screen(Vector3(-8, 0, 8)), false, false)
	check(sent[-1].command == &"attack_move" and sent[-1].target == null, "the armed attack on the ground: attack-move")
	armed.arm_order(&"guard")
	select_input.left_at(_screen(Vector3(-8, 0, 8)), false, false)
	check(sent[-1].command == &"guard_area", "the armed guard on the ground: guard the area")
	armed.arm_order(&"move")
	select_input.left_at(_screen(Vector3(10, 0.5, 0)), false, false)
	check(sent[-1].command == &"move" and sent[-1].target == null, "the armed move goes to the point even over a body")
	var clicks: Array = []
	select_input.armed_clicked.connect(func(mode: StringName, at: Vector2) -> void: clicks.append([mode, at]))
	armed.arm(&"fireball", 3)
	select_input.left_at(Vector2(100, 100), false, false)
	check(clicks == [[&"fireball", Vector2(100, 100)]] and armed.is_armed() and armed.payload == 3, "a game's mode: its click goes to the game, which decides when to disarm")


func test_left_click_selects_shows_or_clears() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	var foe := _unit(Vector3(10, 0.5, 0), 2)
	await physics()
	var others: Array = []
	var empties: Array = []
	select_input.clicked_other.connect(func(body: Node) -> void: others.append(body))
	select_input.clicked_empty.connect(func() -> void: empties.append(true))
	select_input.left_at(_screen(Vector3(0, 0.5, 0)), false, false)
	check(selection.units() == [mine], "a click on an own unit selects it")
	select_input.left_at(_screen(Vector3(10, 0.5, 0)), false, false)
	check(selection.units() == [mine] and others == [foe.body], "a foe: shown, the selection stays")
	select_input.left_at(_screen(Vector3(-15, 0, -15)), true, false)
	check(selection.units() == [mine], "Shift on the ground keeps it")
	select_input.left_at(_screen(Vector3(-15, 0, -15)), false, false)
	check(selection.is_empty() and empties.size() == 1, "a plain click on the ground clears it")


func test_box_from_mouse_events() -> void:
	_rig()
	var a := _unit(Vector3(0, 0.5, 0))
	var b := _unit(Vector3(3, 0.5, 3))
	await physics()
	var from := _screen(Vector3(-5, 0, -5))
	var to := _screen(Vector3(6, 0, 6))
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, true, from))
	select_input._on_event(_motion(from + Vector2(2, 1)))
	check(not select_input.is_boxing(), "under the threshold: still a click")
	select_input._on_event(_motion(to))
	check(select_input.is_boxing(), "past it: a box")
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, false, to))
	check(selection.has(a) and selection.has(b), "the box selected both")


func test_order_button_with_no_menu_is_a_plain_right_click() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	await physics()
	selection.select_only([mine])
	var button := RtsOrderButton.new()
	button.order_input = order_input
	button.pointer = pointer
	root.add_child(button)
	var press := _screen(Vector3(5, 0, 5))
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, true, press))
	button._process(2.0)
	check(not button.is_open(), "no menu: a hold opens nothing")
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, false, press))
	check(sent.size() == 1 and sent[-1].command == &"move", "released after a long hold: still the plain right click")


func test_radial_menu_tap_hold_and_center() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	await physics()
	selection.select_only([mine])
	var menu: RtsRadialMenu = MENU.instantiate()
	root.add_child(menu)
	var button := RtsOrderButton.new()
	button.menu = menu
	button.order_input = order_input
	button.pointer = pointer
	root.add_child(button)
	var layout := menu.layout
	var commands: Array = layout.ring_entries()[0]
	var ids := commands.map(func(e: RtsMenuEntry) -> StringName: return e.command)
	check(ids == [&"move", &"attack", &"guard", &"guard_area", &"attack_move", &"retreat"], "the first ring fills from the command catalog: %s" % [ids])
	check((layout.ring_entries()[1] as Array).size() == 8, "the second from the formations")
	var press := _screen(Vector3(5, 0, 5))
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, true, press))
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, false, press))
	check(sent.size() == 1 and sent[-1].command == &"move" and not menu.is_open(), "a tap is the plain right click")
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, true, press))
	button._process(0.3)
	check(menu.is_open(), "held 0.25 s: the menu opens where it was pressed")
	var on_attack := press + RtsRadialLayout.slot_offset(commands.size(), 1, layout.ring_mid(0))
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, false, on_attack))
	check(sent.size() == 2 and sent[-1].command == &"attack_move" and near(sent[-1].point, Vector3(5, 0, 5), 0.05), "released on attack over the ground: attack-move at the press point")
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, true, press))
	button._process(0.3)
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, false, press))
	check(sent.size() == 2 and not menu.is_open(), "released in the center: cancelled")
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, true, press))
	button._process(0.3)
	var on_line := press + RtsRadialLayout.slot_offset(8, 0, layout.ring_mid(1))
	button._on_view_event(_button(MOUSE_BUTTON_RIGHT, false, on_line))
	check(sent.size() == 3 and sent[-1].command == &"move" and sent[-1].formation == &"line", "a formation entry: the right click there, in it")


func test_command_card() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	await physics()
	selection.select_only([mine])
	var command := RtsCommandInput.new()
	command.install_keymap = true
	root.add_child(command)
	var card := RtsCommandCard.new()
	card.order_input = order_input
	card.command_input = command
	root.add_child(card)
	var buttons := card.buttons()
	check(buttons.size() == 6 + 8, "a button per command and per formation: %d" % buttons.size())
	check(buttons[1].text.begins_with("Attack") and buttons[1].text.ends_with("[A]"), "with its key: %s" % buttons[1].text)
	check(buttons[6].text.ends_with("[Alt+1]"), "formation keys too: %s" % buttons[6].text)
	check(buttons.all(func(b: Button) -> bool: return b.focus_mode == Control.FOCUS_NONE), "buttons never take the keyboard")
	buttons[1].pressed.emit()
	check(armed.mode == &"attack" and sent.is_empty(), "attack: armed for the next left click")
	buttons[0].pressed.emit()
	check(armed.mode == &"move", "another command replaces it")
	buttons[5].pressed.emit()
	check(not armed.is_armed() and said[-1][0] == RtsRefusal.NO_ANCHOR, "retreat happens now (no anchor here: refused)")
	buttons[9].pressed.emit()
	check(sent[-1].command == RtsOrders.FORMATION and sent[-1].formation == &"phalanx", "a formation: the selection keeps it")


func test_formation_and_group_keys_without_any_menu() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	selection.select_only([mine])
	selection.define_group(0)
	selection.clear()
	var keys := RtsGroupKeys.new()
	keys.selection = selection
	root.add_child(keys)
	var command := RtsCommandInput.new()
	command.selection = selection
	command.orders = orders
	command.pointer = pointer
	command.armed = armed
	command.order_input = order_input
	command.group_keys = keys
	root.add_child(command)
	var alt_one := _key(KEY_1, true)
	check(not keys.handle(alt_one) and selection.is_empty(), "Alt+1 is not a group key")
	selection.select_only([mine])
	command._input(alt_one)
	check(sent[-1].command == RtsOrders.FORMATION and sent[-1].formation == &"line", "Alt+1 keeps the first formation")
	selection.clear()
	command._input(_key(KEY_1))
	check(selection.units() == [mine], "1 picks group 1")
	command._input(_key(KEY_A))
	check(armed.mode == &"attack", "A arms attack")
	command._input(_key(KEY_M))
	check(armed.mode == &"move", "M arms move instead")


func test_a_modal_blocks_the_world() -> void:
	_rig()
	var mine := _unit(Vector3(0, 0.5, 0))
	await physics()
	var modal := Control.new()
	root.add_child(modal)
	modal.add_to_group(RtsWorldInput.modal_group)
	check(RtsWorldInput.blocked(select_input), "blocked while a modal is open")
	var at := _screen(Vector3(0, 0.5, 0))
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, true, at))
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, false, at))
	check(selection.is_empty(), "no click reaches the world")
	modal.queue_free()
	await tree.process_frame
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, true, at))
	select_input._on_event(_button(MOUSE_BUTTON_LEFT, false, at))
	check(selection.units() == [mine], "it does once the modal is gone")


func test_keymap_adds_only_missing_actions() -> void:
	InputMap.add_action(&"rts_order_attack_probe")
	if InputMap.has_action(&"rts_order_attack"):
		InputMap.erase_action(&"rts_order_attack")
	InputMap.add_action(&"rts_order_attack")
	var mine := InputEventKey.new()
	mine.physical_keycode = KEY_K
	InputMap.action_add_event(&"rts_order_attack", mine)
	RtsKeymap.install()
	var events := InputMap.action_get_events(&"rts_order_attack")
	check(events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_K, "a game's binding is kept")
	check(InputMap.has_action(&"rts_group_set_1") and InputMap.has_action(&"rts_camera_pan_left"), "the missing ones are added")
	var store := InputMap.action_get_events(&"rts_group_set_1")[0] as InputEventKey
	check(store.command_or_control_autoremap, "group-set keys: Cmd on macOS, Ctrl elsewhere")
	var ctrl_only := RtsKeymap.bindings(false)[&"rts_group_set_1"][0] as InputEventKey
	check(ctrl_only.ctrl_pressed and not ctrl_only.command_or_control_autoremap, "configurable: Ctrl everywhere")
	InputMap.erase_action(&"rts_order_attack")
	InputMap.erase_action(&"rts_order_attack_probe")
	RtsKeymap.install()


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


func _key(code: Key, alt := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.alt_pressed = alt
	return event
