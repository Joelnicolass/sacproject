extends Node

## F27 test bed: own_count own Troggs in a cluster ahead of the local wizard and one enemy
## Druid foe_gap_m further on. Every creature holds still until ordered (idle_aggro off), so
## only an order starts the fight.
## check_tick selects the cluster through Selection.select_rect with the screen rectangle
## around it (the same call a left drag ends in) and aims the camera's debug pointer at the
## Druid, so the next order_units goes to it.
## own_tags (RFC-025): when set, the own creatures cycle through these tags instead of own_tag
## (selection_many.tscn: 150 units of 3 types). Online, only the server spawns (through the
## UnitSpawner, so they replicate) and each peer finds its units under %Units.
## The overlay adds the RFC-025 measures: sel, ordenadas, filas/ancho, rect_us, order_us, frame_ms.

@export var world: Node
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var log_label: Label

@export_group("Layout")
@export var own_tag := "ycro"
## Empty = every own creature is own_tag.
@export var own_tags: PackedStringArray = []
@export var own_count := 4
@export var foe_tag := "nmuh"
@export var foe_slot := 2
@export var ahead_m := 12.0
@export var spacing_m := 3.0
@export var foe_gap_m := 40.0
## The foe attacks whoever comes within sight by itself (F79: it strikes a still selected creature).
@export var foe_aggro := false
@export var rect_pad_px := 24.0
@export var settle_frames := 4

var _own: Array[Node3D] = []
var _foe: Node3D
var _deaths: PackedStringArray = []
var _rect := ""
var _served := false
var _net_children := -1
var _server_ordered := -1
## Measures read by flows (assert prop) and shown in the overlay.
var sel_count := 0
var ordered_count := 0
## Own creatures whose floating health bar shows (only the selected ones draw one).
var bars_count := 0
var rect_us := 0
var order_us := 0
var frame_ms := 0.0
var cpu_ms := 0.0
var draw_calls := 0
var _frames := PackedFloat32Array()
var _last_us := 0


func _ready() -> void:
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_select_cluster()


func _tags() -> PackedStringArray:
	return own_tags if not own_tags.is_empty() else PackedStringArray([own_tag])


func _grid(wizard: Node3D, serial: int) -> Dictionary:
	var ahead: Vector3 = wizard.call("facing_flat")
	var right := ahead.cross(Vector3.UP)
	var center := wizard.global_position + ahead * ahead_m
	var columns := ceili(sqrt(float(own_count)))
	var col := (serial - 1) % columns
	var row := floori(float(serial - 1) / columns)
	return {
		"at": center + right * (col - 0.5 * (columns - 1)) * spacing_m + ahead * row * spacing_m,
		"ahead": ahead,
		"center": center,
	}


## Online server: the units are made through the spawner so every peer gets them.
func _serve(wizard: Node3D, slot: int) -> void:
	var spawner: Node = world.get_node("UnitSpawner")
	var tags := _tags()
	for i in own_count:
		var tag := tags[i % tags.size()]
		var cell := _grid(wizard, i + 1)
		var ahead: Vector3 = cell["ahead"]
		var at: Vector3 = cell["at"]
		var unit: Node3D = spawner.call("spawn_unit", {
			"tag": tag, "label": str(GameData.creature(tag).display_name), "slot": slot,
			"x": at.x, "y": at.y, "z": at.z, "yaw": atan2(ahead.x, ahead.z)})
		unit.set("idle_aggro", false)
	var center: Vector3 = _grid(wizard, 1)["center"]
	var foe_ahead: Vector3 = wizard.call("facing_flat")
	var foe_at := center + foe_ahead * foe_gap_m
	var foe: Node3D = spawner.call("spawn_unit", {
		"tag": foe_tag, "label": str(GameData.creature(foe_tag).display_name), "slot": foe_slot,
		"x": foe_at.x, "y": foe_at.y, "z": foe_at.z, "yaw": atan2(-foe_ahead.x, -foe_ahead.z)})
	foe.set("idle_aggro", foe_aggro)
	print("servidor: grupo %d en slot %d" % [own_count, slot])


## Online client (and server): own creatures and the foe, found under %Units.
func _collect_net() -> void:
	var units: Node = world.get_node("%Units")
	if units.get_child_count() == _net_children:
		return
	_net_children = units.get_child_count()
	_own.clear()
	for node in units.get_children():
		if int(node.get("owner_slot")) == MpKit.local_slot() and node is Node3D:
			_own.append(node)
		elif int(node.get("owner_slot")) == foe_slot and node is Node3D:
			_foe = node


func _start() -> void:
	var wizard: Node3D = world.call("local_wizard")
	if wizard == null or not _own.is_empty() or MpKit.is_networked():
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	var tags := _tags()
	for i in own_count:
		var cell := _grid(wizard, i + 1)
		_own.append(_spawn(tags[i % tags.size()], MpKit.local_slot(), cell["at"], cell["ahead"], i + 1))
	var ahead: Vector3 = wizard.call("facing_flat")
	_foe = _spawn(foe_tag, foe_slot, (_grid(wizard, 1)["center"] as Vector3) + ahead * foe_gap_m, -ahead, 1)
	_foe.set("idle_aggro", foe_aggro)
	print("grupo %d %s slot %d, %s slot %d a %.0f m" % [own_count, ",".join(tags), MpKit.local_slot(), foe_tag, foe_slot, foe_gap_m])


func _spawn(tag: String, slot: int, at: Vector3, facing: Vector3, serial: int) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.set("creature_tag", tag)
	unit.name = "%s%d" % [str(GameData.creature(tag).display_name), serial]
	unit.set("owner_slot", slot)
	unit.set("idle_aggro", false)
	arena.add_child(unit)
	unit.global_position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	unit.died.connect(_on_died)
	return unit


func _select_cluster() -> void:
	var camera := get_viewport().get_camera_3d()
	if MpKit.is_networked():
		_collect_net()
	if camera == null or _own.is_empty():
		return
	var rect := Rect2()
	for i in _own.size():
		var spot := camera.unproject_position(_center(_own[i]))
		rect = Rect2(spot, Vector2.ZERO) if i == 0 else rect.expand(spot)
	rect = rect.grow(rect_pad_px)
	world.get_node("%Selection").call("select_rect", rect.position, rect.end, false)
	_rect = "rect (%d, %d)-(%d, %d)" % [rect.position.x, rect.position.y, rect.end.x, rect.end.y]
	if is_instance_valid(_foe):
		var aim := camera.unproject_position(_center(_foe))
		world.get_node("%Camera").set("debug_pointer", aim)
		_rect += " druid (%d, %d)" % [aim.x, aim.y]
	print(_rect)


func _center(unit: Node3D) -> Vector3:
	var visual := unit.get_node("Tilt/Mesh")
	return unit.global_position + Vector3.UP * float(visual.call("body_height")) * 0.5


func _on_died(tag: String, slot: int, _at: Vector3) -> void:
	var line := "muere %s" % str(GameData.creature(tag).display_name)
	_deaths.append(line)
	print("%s slot %d" % [line, slot])


func _process(_delta: float) -> void:
	_measure()
	if MpKit.is_networked():
		_net_tick()
	if log_label == null:
		return
	var attacking := 0
	for unit in _own:
		if is_instance_valid(unit) and unit.get("target") == _foe and _foe != null:
			attacking += 1
	var foe_text := "Druid -"
	if is_instance_valid(_foe):
		var health := _foe.get_node("Health")
		foe_text = "%s %d/%d" % [_foe.call("display_name"), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))]
	var label := str(GameData.creature(own_tag).display_name) if own_tags.is_empty() else "propias"
	var orders := world.get_node("%Orders")
	log_label.text = "%d %s · %s · atacan %d\n%s\n%s\nsel %d · barras %d · ordenadas %d · filas %d ancho %.1f · rect_us %d · order_us %d · frame_ms %.2f (cpu %.2f)" % [
		_own.size(), label, foe_text, attacking, _rect, " · ".join(_deaths),
		sel_count, bars_count, ordered_count, int(orders.get("last_rows")), float(orders.get("last_width")),
		rect_us, order_us, frame_ms, cpu_ms]


## Online: the server spawns the group once its client's wizard exists, then reports orders.
func _net_tick() -> void:
	if MpKit.is_server():
		if not _served:
			for node in get_tree().get_nodes_in_group("wizard"):
				if int(node.get("owner_slot")) > 0:
					_served = true
					_serve(node, int(node.get("owner_slot")))
					break
		_collect_server()
	else:
		_collect_net()


## Server: how many of the client's creatures are under an order.
func _collect_server() -> void:
	var count := 0
	var total := 0
	for node in world.get_node("%Units").get_children():
		if int(node.get("owner_slot")) == 1:
			total += 1
			if bool(node.get("ordered")):
				count += 1
	if count != _server_ordered:
		_server_ordered = count
		print("servidor: %d de %d con orden" % [count, total])


func _measure() -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append((now - _last_us) / 1000.0)
		if _frames.size() > 120:
			_frames.remove_at(0)
		var sum := 0.0
		for ms in _frames:
			sum += ms
		frame_ms = sum / _frames.size()
	_last_us = now
	cpu_ms = (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var selection := world.get_node("%Selection")
	sel_count = int(selection.call("size"))
	rect_us = int(selection.get("last_rect_us"))
	order_us = int(world.get_node("%Orders").get("last_apply_us"))
	var ordered := 0
	var bars := 0
	for unit in _own:
		if not is_instance_valid(unit):
			continue
		if bool(unit.get("ordered")):
			ordered += 1
		var bar := unit.get_node_or_null("HealthBar") as Node3D
		if bar and bar.visible:
			bars += 1
	ordered_count = ordered
	bars_count = bars
