extends Node

## RFC-038 038d window probe on debug/orders_radial.tscn (8 own Troggs). Drives REAL input through the viewport (mouse buttons,
## motion, keys) and reads the result: it never calls the product's own methods to give an order.
##   1. a right TAP (< hold_s) orders a move: the group ends at the point and the radial menu never opens
##   2. a right HOLD opens the radial menu; moving to the Cuña wedge highlights it; releasing gives the move order to the PRESS point in
##      the wedge: the 8 end within SLOT_M of their wedge slots, and the point they were given is the press point
##   3. a right tap after it: the formation was kept (wedge again, at the new point)
##   4. Tab HOLD opens the menu at the pointer; Mover from the inner ring; releasing sends the group to the pointer, still in wedge
##   5. Alt+3 stores the 3rd formation of the catalog and leaves the selection alone (it is not group 3)
## Captures go to `out_dir`. Prints RADIAL_PROBE lines and sets `finished` / `failures` for the flow.

const SLOT_M := 1.0
## A tap that moves a whole wedge back across itself: the greedy slot match crosses paths, bodies jostle.
const TAP_SLOT_M := 2.0
const POINTS := [Vector2(300.0, 500.0), Vector2(300.0, 400.0), Vector2(300.0, 530.0), Vector2(330.0, 380.0)]

@export var world: Node
@export var out_dir := "res://agent/out/f038d"
@export var arrive_limit_s := 60.0

var failures := 0
var finished := false


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail := "") -> void:
	print("RADIAL_PROBE %s %s %s" % ["ok" if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func _button(index: int, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	if pressed:
		event.button_mask = 1 << (index - 1)
	Input.parse_input_event(event)


func _motion(at: Vector2, from: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - from
	event.button_mask = mask
	Input.parse_input_event(event)


func _key(code: Key, pressed: bool, alt := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.alt_pressed = alt
	event.pressed = pressed
	Input.parse_input_event(event)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join(name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("RADIAL_PROBE shot %s" % path)


func _own_units() -> Array:
	var units: Array = []
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == MpKit.local_slot() and not bool(node.call("is_dead")):
			units.append(node)
	return units


func _center(units: Array) -> Vector2:
	var sum := Vector2.ZERO
	for unit in units:
		sum += Vector2(unit.global_position.x, unit.global_position.z)
	return sum / maxf(float(units.size()), 1.0)


func _ground(screen: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 1
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	return Vector3.INF if hit.is_empty() else hit["position"]


func _all_idle(units: Array) -> bool:
	for unit in units:
		if int(unit.get("mode")) == UnitBody.Mode.MOVE:
			return false
	return true


## Waits until every creature is within `SLOT_M` of its slot (at least `min_s` first, so the order has started), or the limit.
func _arrive(units: Array, min_s := 1.0) -> float:
	var started := Time.get_ticks_msec()
	await _wait(min_s)
	while _worst_off_slot(units) > 0.8 and (Time.get_ticks_msec() - started) < arrive_limit_s * 1000.0:
		await _wait(0.5)
	if _worst_off_slot(units) > SLOT_M:
		for unit in units:
			var anchor := Vector3(unit.get_node("Orders").call("anchor"))
			print("RADIAL_PROBE off-slot %s mode %d at %s slot %s offset %s %.2f m" % [unit.name, int(unit.get("mode")), unit.global_position, anchor, unit.get_node("Orders").get("offset"), Vector2(unit.global_position.x - anchor.x, unit.global_position.z - anchor.z).length()])
	await _wait(1.0)
	return (Time.get_ticks_msec() - started) / 1000.0


func _formation_of(unit: Node) -> StringName:
	return unit.get_node("Orders").get("formation_id")


func _all_formation(units: Array, id: StringName) -> bool:
	for unit in units:
		if _formation_of(unit) != id:
			return false
	return not units.is_empty()


func _worst_off_slot(units: Array) -> float:
	var worst := 0.0
	for unit in units:
		var anchor := Vector3(unit.get_node("Orders").call("anchor"))
		worst = maxf(worst, Vector2(unit.global_position.x - anchor.x, unit.global_position.z - anchor.z).length())
	return worst


## The offsets the creatures were given are, as a set, the slots of the formation (same check as debug/formation_cases.gd).
func _offsets_are(units: Array, formation_id: StringName) -> bool:
	var orders: Node = world.get_node("%Orders")
	var size := 0.0
	for unit in units:
		size = maxf(size, 2.0 * float(orders.call("_half_size", unit)))
	var spacing := minf(float(orders.get("spacing_per_size")) * size + float(orders.get("spacing_base")), float(orders.get("max_spacing")))
	var want: Array[Vector2] = orders.get("catalog").find(formation_id).slots(units.size(), spacing, 0.0, 0)
	var got: Array[Vector2] = []
	for unit in units:
		got.append(unit.get_node("Orders").get("offset"))
	for slot in want:
		var found := -1
		for i in got.size():
			if got[i].distance_to(slot) <= 0.001:
				found = i
				break
		if found < 0:
			return false
		got.remove_at(found)
	return got.is_empty()


## Screen position of an entry of the open menu's ring.
func _entry_spot(menu: RadialMenu, id: StringName) -> Vector2:
	var layout := menu.layout
	var factor := menu.hud_scale.factor(get_viewport().get_visible_rect().size.y)
	var origin := menu.position + menu.size * 0.5
	for ring in [[layout.inner, layout.inner_mid()], [layout.outer, layout.outer_mid()]]:
		var entries: Array = ring[0]
		for i in entries.size():
			if entries[i].id == id:
				return origin + RadialLayout.slot_offset(entries.size(), i, float(ring[1])) * factor
	return origin


## The point the group's last order was given (every creature holds the same one).
func _orders_point(units: Array) -> Vector3:
	return units[0].get_node("Orders").get("point")


func _tap(button: int, at: Vector2) -> void:
	_button(button, true, at)
	await _frames(2)
	_button(button, false, at)
	await _frames(2)


func _run() -> void:
	await _wait(4.0)
	var menu: RadialMenu = world.get_node("%RadialMenu")
	var battle: Node = world.get_node("%Battle")
	var selection: Node = world.get_node("%Selection")
	var press := InputEventAction.new()
	press.action = &"check_tick"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	var units := _own_units()
	_check("8 Troggs", units.size() == 8, str(units.size()))
	_check("selected", int(selection.get("count")) == 8, str(selection.get("count")))
	_check("starts in line", _all_formation(units, &"line"))
	var grounds: Array[Vector3] = []
	for spot in POINTS:
		grounds.append(_ground(spot))
		_check("ground at %s" % spot, grounds[-1] != Vector3.INF, str(grounds[-1]))

	# 1. A right tap is the order of always.
	var start := _center(units)
	var seconds := 0.0
	var worst := 0.0
	_motion(POINTS[0], POINTS[0], 0)
	await _frames(2)
	await _tap(MOUSE_BUTTON_RIGHT, POINTS[0])
	_check("tap does not open the menu", not menu.is_open())
	_check("tap says Orden", battle.get("text") == "Orden", str(battle.get("text")))
	seconds = await _arrive(units)
	var target := Vector2(grounds[0].x, grounds[0].z)
	_check("tap moved the group to the point", _center(units).distance_to(target) <= 2.0 and _center(units).distance_to(start) > 4.0,
		"center %.1f m from the point after %.1f s" % [_center(units).distance_to(target), seconds])
	_check("still in line", _all_formation(units, &"line"))

	# 2. A right hold opens the menu; Cuña by angle; release orders a move to the press point in that formation.
	_button(MOUSE_BUTTON_RIGHT, true, POINTS[1])
	await _wait(0.1)
	_check("not open before hold_s", not menu.is_open())
	await _wait(0.4)
	_check("hold opens the menu", menu.is_open())
	_check("menu centered on the press", (menu.position + menu.size * 0.5).distance_to(POINTS[1]) < 1.0, str(menu.position + menu.size * 0.5))
	await _shot("1_radial_open.png")
	var attack := _entry_spot(menu, &"attack")
	_motion(attack, POINTS[1], MOUSE_BUTTON_MASK_RIGHT)
	await _wait(0.4)
	_check("pointer on Atacar highlights it", menu.hovered != null and menu.hovered.id == &"attack")
	await _shot("2_radial_hover_attack.png")
	var wedge := _entry_spot(menu, &"wedge")
	_motion(wedge, attack, MOUSE_BUTTON_MASK_RIGHT)
	await _wait(0.4)
	_check("pointer on Cuña highlights it", menu.hovered != null and menu.hovered.id == &"wedge", str(menu.hovered.id if menu.hovered else null))
	await _shot("3_radial_hover_wedge.png")
	_button(MOUSE_BUTTON_RIGHT, false, wedge)
	await _wait(0.3)
	_check("release closes the menu", not menu.is_open() and not menu.visible)
	_check("Cuña stored on the 8", _all_formation(units, &"wedge"))
	_check("says Cuña", battle.get("text") == "Cuña", str(battle.get("text")))
	seconds = await _arrive(units)
	worst = _worst_off_slot(units)
	_check("one gesture: wedge at the press point, each within %.1f m of its slot" % SLOT_M, worst <= SLOT_M, "worst %.2f m after %.1f s" % [worst, seconds])
	_check("offsets are the wedge's", _offsets_are(units, &"wedge"))
	_check("the order point is the press point", _orders_point(units).distance_to(grounds[1]) < 0.5, str(_orders_point(units)))
	_check("selection kept", int(selection.get("count")) == 8)
	await _shot("4_wedge_at_press_point.png")

	# 3. A right tap after it keeps the formation.
	await _tap(MOUSE_BUTTON_RIGHT, POINTS[2])
	seconds = await _arrive(units)
	worst = _worst_off_slot(units)
	_check("tap keeps the wedge, within %.1f m of its slots (a crowd reordering)" % TAP_SLOT_M, worst <= TAP_SLOT_M and _offsets_are(units, &"wedge") and _orders_point(units).distance_to(grounds[2]) < 0.5, "worst %.2f m after %.1f s" % [worst, seconds])

	# 4. Tab hold opens the menu at the pointer; Mover; release orders there.
	_motion(POINTS[3], POINTS[2], 0)
	await _frames(2)
	_key(KEY_TAB, true)
	await _wait(0.1)
	_check("Tab: not open before hold_s", not menu.is_open())
	await _wait(0.4)
	_check("Tab hold opens the menu", menu.is_open())
	_check("Tab menu at the pointer", (menu.position + menu.size * 0.5).distance_to(POINTS[3]) < 1.0)
	var move_spot := _entry_spot(menu, &"move")
	_motion(move_spot, POINTS[3], 0)
	await _wait(0.4)
	_check("pointer on Mover highlights it", menu.hovered != null and menu.hovered.id == &"move", str(menu.hovered.id if menu.hovered else null))
	await _shot("5_radial_tab_move.png")
	_key(KEY_TAB, false)
	await _wait(0.3)
	_check("Tab release closes the menu", not menu.is_open())
	_check("nothing stays armed", battle.get("armed") == "", str(battle.get("armed")))
	seconds = await _arrive(units)
	worst = _worst_off_slot(units)
	_check("Mover: wedge kept, at the Tab point, each within %.1f m" % SLOT_M, worst <= SLOT_M and _offsets_are(units, &"wedge") and _orders_point(units).distance_to(grounds[3]) < 0.5, "worst %.2f m after %.1f s" % [worst, seconds])

	# 4b. Releasing in the center cancels.
	var before := _orders_point(units)
	_button(MOUSE_BUTTON_RIGHT, true, POINTS[0])
	await _wait(0.5)
	_check("hold again opens it", menu.is_open())
	_button(MOUSE_BUTTON_RIGHT, false, POINTS[0])
	await _wait(0.3)
	_check("center release cancels: no new order", _orders_point(units) == before and not menu.is_open(), "%s -> %s open %s hovered %s" % [before, _orders_point(units), menu.is_open(), menu.hovered.id if menu.hovered else null])

	# 5. Alt+3: the 3rd formation, and the selection stays.
	_key(KEY_3, true, true)
	await _frames(2)
	_key(KEY_3, false, true)
	await _frames(3)
	var third: StringName = world.get_node("%Orders").get("catalog").formations[2].id
	_check("Alt+3 stores %s" % third, _all_formation(units, third), str(_formation_of(units[0])))
	_check("Alt+3 says its name", battle.get("text") == str(world.get_node("%Orders").get("catalog").formations[2].display_name), str(battle.get("text")))
	_check("Alt+3 is not group 3", int(selection.get("count")) == 8, str(selection.get("count")))
	await _shot("5_alt3.png")

	print("RADIAL_PROBE %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	finished = true
