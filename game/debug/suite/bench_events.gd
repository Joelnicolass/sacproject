class_name BenchEvents
extends RefCounted

## The script of a bench match with an AI (RFC-024 024c): the BenchEvent of the rules happen at their second, and what they
## measure goes to the report under `probes`. It only puts bodies on the field (UnitSpawner, like a summon) or kills one
## (Health.damage, like a hit) and watches; it never tells the AI anything. Debug code.

var world: Node
var audit: AiAudit
var sides: Dictionary
var rules: BenchRules

var _pending: Array[BenchEvent] = []
var _live: Array[Dictionary] = []
var results: Dictionary = {}
var _defend := {}
var _guard := {}


func _init(p_world: Node, p_audit: AiAudit, p_sides: Dictionary, p_rules: BenchRules) -> void:
	world = p_world
	audit = p_audit
	sides = p_sides
	rules = p_rules
	for event in rules.events:
		_pending.append(event)
	_pending.sort_custom(func(a: BenchEvent, b: BenchEvent) -> bool: return a.at_s < b.at_s)


## Once per physics tick of the bench, with the audit's tick.
func step(tick: int) -> void:
	while not _pending.is_empty() and tick >= int(round(_pending[0].at_s * 60.0)):
		_fire(_pending.pop_front(), tick)
	for entry in _live:
		_watch(entry, tick)
	if tick == 3 and not sides.is_empty():
		_scan_probe()
	if rules.probe == "defend":
		_defend_probe(tick)
	elif rules.probe == "guard":
		_guard_probe(tick)


func _wizard(slot: int) -> Node3D:
	for wizard in world.get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


func _other_wizard(slot: int) -> Node3D:
	for wizard in world.get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) != slot:
			return wizard as Node3D
	return null


func _anchor_body(event: BenchEvent) -> Node3D:
	var group := &"wizard"
	match event.anchor:
		"altar":
			group = Altar.GROUP
		"structure":
			group = &"structure"
	for node in world.get_tree().get_nodes_in_group(group):
		if int(node.get("owner_slot")) == event.from_slot:
			return node as Node3D
	return _wizard(event.from_slot)


func _fire(event: BenchEvent, tick: int) -> void:
	var entry := {"event": event, "tick": tick, "node": null, "in_sight_tick": -1, "attack_tick": -1, "removed_tick": -1, "tracked": false}
	if event.action == "spawn":
		entry["node"] = _spawn(event)
		print("bench: %s en el tick %d" % [event.label, tick])
	elif event.action == "stun":
		var body := world.get_node_or_null("%Units/" + event.user) as Node3D
		entry["node"] = body
		if body:
			print("bench: %s aturde a %s en el tick %d: %s" % [event.label, event.user, tick, body.get_node("Afflictions/Stunned").call("stun_with_cooldown", 120)])
	elif event.action == "ability":
		entry["node"] = _use_ability(event, tick)
	elif event.action == "attack":
		entry["node"] = _order_attack(event, tick)
	else:
		var victim := world.get_node_or_null("%Units/" + event.victim) as Node3D
		entry["node"] = victim
		if victim != null:
			victim.get_node("Health").call("damage", 1.0e9, event.slot)
			print("bench: %s mata a %s en el tick %d" % [event.label, event.victim, tick])
	_live.append(entry)


## F152: `user` uses its active ability like a click (UnitBody.use_ability); a refusal is logged with the body's name.
func _use_ability(event: BenchEvent, tick: int) -> Node3D:
	var body := world.get_node_or_null("%Units/" + event.user) as Node3D
	if body == null:
		push_warning("bench: no hay un cuerpo %s para usar la habilidad" % event.user)
		return null
	var foe := world.get_node_or_null("%Units/" + event.target) as Node3D if not event.target.is_empty() else null
	if event.target_soul:
		foe = Soul.on_corpse(foe)
	var at := Vector3(event.point.x, 0.0, event.point.y)
	at.y = BodyNudge.ground_y(body, at)
	var reason: String = body.call("use_ability", at, foe)
	print("bench: %s usa la habilidad: %s (tick %d)" % [event.user, "ok" if reason.is_empty() else "rechazada, " + reason, tick])
	return body


## F129: `user` is ordered to attack `target` (Orders.apply_for with the event's slot: the same validation as a human's click).
func _order_attack(event: BenchEvent, tick: int) -> Node3D:
	var body := world.get_node_or_null("%Units/" + event.user) as Node3D
	var foe := world.get_node_or_null("%Units/" + event.target) as Node3D if not event.target.is_empty() else null
	if body == null:
		push_warning("bench: no hay un cuerpo %s para atacar" % event.user)
		return null
	var at := foe.global_position if foe != null else Vector3(event.point.x, 0.0, event.point.y)
	world.get_node("%Orders").call("apply_for", event.slot, [body], event.order, at, foe if event.order == "attack" else null, 0.0)
	print("bench: %s ataca a %s (tick %d)" % [event.user, event.target if foe != null else str(event.point), tick])
	return body


func _spawn(event: BenchEvent) -> Node3D:
	var base := _anchor_body(event)
	var other := _other_wizard(event.from_slot)
	if base == null:
		return null
	var dir := Vector3(0.0, 0.0, 1.0)
	if other != null:
		dir = other.global_position - base.global_position
		dir.y = 0.0
		dir = dir.normalized()
	var at := find_spot(world, base.global_position, dir, event.distance_m, event.angle_deg, event.anchor == "wizard")
	if is_nan(at.x):
		push_warning("bench: no hay un lugar a %.0f m para %s" % [event.distance_m, event.label])
		return null
	var type := GameData.creature(event.tag)
	return world.get_node("UnitSpawner").call("spawn_unit", {
		"tag": event.tag, "label": type.display_name if type else event.tag, "slot": event.slot,
		"x": at.x, "y": at.y, "z": at.z, "yaw": atan2(-dir.x, -dir.z),
		"npc": event.npc, "peasant": type != null and type.peasant,
	}) as Node3D


func _watch(entry: Dictionary, tick: int) -> void:
	var event: BenchEvent = entry["event"]
	## The watched body may already be freed (a killed NPC whose corpse faded): check before typing it.
	var raw: Variant = entry["node"]
	var gone: bool = raw != null and not is_instance_valid(raw)
	var node: Node3D = null if raw == null or gone else raw as Node3D
	var side: AiSide = sides.get(event.from_slot)
	match event.watch:
		"tracked":
			if side != null and node != null and side.perception.find(node) != null:
				entry["tracked"] = true
		"untracked":
			if side != null and (node != null or gone) and int(entry["removed_tick"]) < 0 and tick > int(entry["tick"]) and (gone or side.perception.find(node) == null):
				entry["removed_tick"] = tick
		"attacked":
			if node == null or not is_instance_valid(node):
				return
			for unit in world.get_tree().get_nodes_in_group("unit"):
				if int(unit.get("owner_slot")) != event.from_slot or unit.call("is_dead") or unit.call("is_summoning"):
					continue
				var body := unit as Node3D
				var flat := Vector2(body.global_position.x - node.global_position.x, body.global_position.z - node.global_position.z).length()
				var sight: float = (unit.get("type") as CreatureType).vision_m
				if int(entry["in_sight_tick"]) < 0 and flat <= sight:
					entry["in_sight_tick"] = tick
				if int(entry["attack_tick"]) < 0 and unit.get("target") == node:
					entry["attack_tick"] = tick
	if node == null:
		return


func _scan_probe() -> void:
	var slot: int = sides.keys()[0]
	var side: AiSide = sides[slot]
	var npc_tracked := 0
	var enemy_altar := false
	for t: AiTrack in side.perception.tracks.values():
		if t.node.is_in_group(&"npc"):
			npc_tracked += 1
		if t.kind == AiTrack.Kind.STRUCTURE and t.node.is_in_group(Altar.GROUP) and AiPerception.owner_slot_of(t.node) != slot:
			enemy_altar = true
	results["scan"] = {
		"npc_tracked": npc_tracked,
		"npc_total": world.get_tree().get_nodes_in_group(&"npc").size(),
		"enemy_altar_tracked": enemy_altar,
		"tracks": side.perception.tracks.size(),
	}


## ai_defend (RFC §6 024c): first tick a foe is within 280 m of the AI wizard; the first attack cast aimed at a foe; the first tick
## two creatures of the AI fight foes.
func _defend_probe(tick: int) -> void:
	if sides.is_empty():
		return
	var slot: int = sides.keys()[0]
	var wizard := _wizard(slot)
	if wizard == null:
		return
	var foes: Array[Node3D] = []
	for unit in world.get_tree().get_nodes_in_group("unit"):
		if int(unit.get("owner_slot")) != slot and not unit.is_in_group(&"npc") and not unit.call("is_dead"):
			foes.append(unit as Node3D)
	if not _defend.has("d280_tick"):
		for foe in foes:
			if foe.global_position.distance_to(wizard.global_position) <= 280.0:
				_defend["d280_tick"] = tick
				break
	if not _defend.has("cast_tick"):
		var side_report: Dictionary = audit.sides_report().get(str(slot), {})
		for cast: Dictionary in side_report.get("casts", []):
			if str(cast["target"]).begins_with("Druid"):
				_defend["cast_tick"] = int(cast["tick"])
				_defend["cast_tag"] = str(cast["tag"])
				break
	if not _defend.has("engaged_tick"):
		var engaged := 0
		for unit in world.get_tree().get_nodes_in_group("unit"):
			if int(unit.get("owner_slot")) != slot or unit.call("is_dead"):
				continue
			var mode: int = unit.get("mode")
			var target: Variant = unit.get("target")
			if (mode == UnitBody.Mode.CHASE or mode == UnitBody.Mode.ATTACK) and target != null and is_instance_valid(target) and int(target.get("owner_slot")) != slot and (target as Node).name.begins_with("Druid"):
				engaged += 1
		if engaged >= 2:
			_defend["engaged_tick"] = tick
			_defend["engaged_units"] = engaged
	results["defend"] = _defend


## ai_guard (RFC §6 024d): the first tick the Manalith of the AI loses health; then the first tick two creatures of the AI are fighting the
## attackers (chasing or striking one of them), and how many guard the Manalith by order. `_guard["engaged_after_ticks"]` is the answer.
func _guard_probe(tick: int) -> void:
	if sides.is_empty():
		return
	var slot: int = sides.keys()[0]
	var manalith: Node3D
	for node in world.get_tree().get_nodes_in_group("structure"):
		if int(node.get("owner_slot")) == slot and not node.is_in_group(MapBuilding.GROUP):
			manalith = node as Node3D
			break
	if manalith == null:
		return
	var health := manalith.get_node_or_null("Health")
	if health != null and not _guard.has("first_hit_tick") and float(health.get("current")) < float(health.get("maximum")):
		_guard["first_hit_tick"] = tick
	if not _guard.has("first_hit_tick"):
		return
	var engaged := 0
	var guarding := 0
	for unit in world.get_tree().get_nodes_in_group("unit"):
		if int(unit.get("owner_slot")) != slot or unit.call("is_dead") or unit.is_in_group(&"npc"):
			continue
		var orders := unit.get_node_or_null("Orders")
		if orders != null and int(orders.get("command")) == 3 and orders.get("target") == manalith:
			guarding += 1
		var mode: int = unit.get("mode")
		var target: Variant = unit.get("target")
		if (mode == UnitBody.Mode.CHASE or mode == UnitBody.Mode.ATTACK) and target != null and is_instance_valid(target) and int(target.get("owner_slot")) == 1:
			engaged += 1
	_guard["max_guarding"] = maxi(int(_guard.get("max_guarding", 0)), guarding)
	if not _guard.has("engaged_tick") and engaged >= 2:
		_guard["engaged_tick"] = tick
		_guard["engaged_units"] = engaged
		_guard["engaged_after_ticks"] = tick - int(_guard["first_hit_tick"])
		_guard["engaged_after_s"] = snappedf(float(tick - int(_guard["first_hit_tick"])) / 60.0, 0.01)
	results["guard"] = _guard


func report() -> Dictionary:
	var out := results.duplicate(true)
	for entry in _live:
		var event: BenchEvent = entry["event"]
		var row := {"at_tick": int(entry["tick"]), "action": event.action}
		match event.watch:
			"tracked":
				row["ever_tracked"] = bool(entry["tracked"])
				var node: Node3D = entry["node"]
				var side: AiSide = sides.get(event.from_slot)
				row["tracked_end"] = side != null and node != null and is_instance_valid(node) and side.perception.find(node) != null
			"untracked":
				row["removed_after_ticks"] = int(entry["removed_tick"]) - int(entry["tick"]) if int(entry["removed_tick"]) >= 0 else -1
			"attacked":
				row["in_sight_tick"] = int(entry["in_sight_tick"])
				row["attack_tick"] = int(entry["attack_tick"])
				row["delay_ticks"] = int(entry["attack_tick"]) - int(entry["in_sight_tick"]) if int(entry["attack_tick"]) >= 0 and int(entry["in_sight_tick"]) >= 0 else -1
		results[event.label] = row
	return results.duplicate(true)


## A spot `distance` m from `from` along `dir` turned `angle_deg` that a body can stand on and walk to: land under it, at
## most 8 m above or below `from`, in the same region of the pathfinder and with a clear line. When that one is not (a cliff,
## a hole, a fount), the angle is moved by 15 degrees to either side until one is. NAN in x when none is.
static func find_spot(world: Node, from: Vector3, dir: Vector3, distance: float, angle_deg: float, strict := true) -> Vector3:
	var terrain := GroundSurface.of(world)
	var nav := world.get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	for attempt in 25:
		var wobble := 15.0 * float((attempt + 1) / 2) * (1.0 if attempt % 2 == 0 else -1.0)
		var turned := dir.rotated(Vector3.UP, deg_to_rad(angle_deg + wobble))
		var at := from + turned * distance
		var ground := float(terrain.height_at(at.x, at.z))
		if is_nan(ground) or (strict and absf(ground - from.y) > 8.0):
			continue
		at.y = ground + 0.2
		if nav != null and nav.is_ready() and not (nav.same_region(from, at) and (not strict or nav.line_clear(from, at))):
			continue
		return at
	return Vector3(NAN, 0.0, 0.0)
