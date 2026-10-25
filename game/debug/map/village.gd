extends Node

## Test bed of the villages (RFC-024 addendum 1, 024b2): High Noon with its Farmers, Taurocks and houses, the
## human Persephone wizard `rules.wizard_distance_m` from the hut (or from one NPC) and his Druid `Hunter`
## beside him, selected and still (idle_aggro off). The NPC wait, process off, under «Aldea en pausa» until
## check_tick (Enter) wakes them. Everything else is the product: order_units on a Farmer, the Structures tab
## (spell_3 = Convert) on the red soul. Variants are the rules: village (the hut), village_cower (Farmer6,
## which has no shelter within 50 m), village_taurock (a Taurock 70 m from Hunter).

@export var world: Node
@export var status_label: Label
@export var settle_frames := 4

var woke := false

var _hunter: Node3D


func _ready() -> void:
	_set_status("Aldea en pausa")
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not woke:
		wake()


func rules() -> VillageRules:
	var rules_value: Variant = world.get("rules")
	return rules_value as VillageRules if rules_value is VillageRules else VillageRules.new()


func hunter() -> Node3D:
	return _hunter


## The NPC process again: the village starts to live.
func wake() -> void:
	woke = true
	for npc in get_tree().get_nodes_in_group("npc"):
		npc.process_mode = Node.PROCESS_MODE_INHERIT
	_set_status("Aldea despierta")
	print("aldea despierta")


func _start() -> void:
	var wizard: Node3D = world.call("local_wizard")
	if wizard == null or _hunter != null or MpKit.is_networked():
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	var rule := rules()
	var focus := _focus_point(rule)
	var terrain := GroundSurface.of(world)
	var spot := focus + Vector3(rule.from_direction.x, 0.0, rule.from_direction.y).normalized() * rule.wizard_distance_m
	spot.y = _ground(terrain, spot.x, spot.z)
	wizard.global_position = spot
	wizard.set("velocity", Vector3.ZERO)
	var side := Vector3(-rule.from_direction.y, 0.0, rule.from_direction.x).normalized()
	var at := spot + side * rule.hunter_offset_m
	at.y = _ground(terrain, at.x, at.z)
	_hunter = world.get_node("UnitSpawner").call("spawn_unit", {
		"tag": "nmuh", "label": "Druid", "slot": MpKit.local_slot(),
		"x": at.x, "y": at.y + 0.2, "z": at.z, "yaw": atan2(focus.x - at.x, focus.z - at.z)})
	_hunter.name = "Hunter"
	_hunter.set("idle_aggro", false)
	_hunter.set("rng_seed", 73)
	world.get_node("%Selection").call("select_only", [_hunter])
	if rule.taurock_gap_m > 0.0:
		_place_taurock(rule.taurock_gap_m, terrain)
		if rule.isolate_taurock:
			_isolate_taurock()
	for _frame in settle_frames:
		await get_tree().physics_frame
	if rule.pause_npcs:
		for npc in get_tree().get_nodes_in_group("npc"):
			npc.process_mode = Node.PROCESS_MODE_DISABLED
	print("aldea: mago en (%.0f, %.0f), Hunter en (%.0f, %.0f), %d NPC en pausa" % [spot.x, spot.z, at.x, at.z, get_tree().get_nodes_in_group("npc").size()])


func _focus_point(rule: VillageRules) -> Vector3:
	if not rule.focus_npc.is_empty():
		var npc := world.get_node_or_null("%Units/" + rule.focus_npc) as Node3D
		if npc != null:
			return npc.global_position
		push_warning("aldea: no hay %s; se usa la casa" % rule.focus_npc)
	return Vector3(rule.focus_hut.x, 0.0, rule.focus_hut.y)


func _place_taurock(gap: float, terrain: GroundSurface) -> void:
	var taurock := world.get_node_or_null("%Units/Taurock1") as Node3D
	if taurock == null:
		return
	var at := _hunter.global_position + Vector3(gap, 0.0, 0.0)
	at.y = _ground(terrain, at.x, at.z)
	taurock.call("warp_to", at)
	print("aldea: Taurock1 a %.0f m de Hunter" % gap)


func _isolate_taurock() -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.name != &"Taurock1":
			npc.remove_from_group("npc")
			npc.queue_free()


func _ground(terrain: GroundSurface, x: float, z: float) -> float:
	var y := float(terrain.height_at(x, z))
	return 0.0 if is_nan(y) else y


func _set_status(text: String) -> void:
	if status_label and status_label.text != text:
		status_label.text = text
