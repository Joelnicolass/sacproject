extends Node

## Probe of the 024b2 criteria (RFC-024 addendum 1), headless, observation only: it puts High Noon in the tree with the
## village rules, runs one case with --case=<name> and prints `PT73 {json}` before it quits.
##   godot --headless --path game --fixed-fps 60 res://agent/fixtures/pt73_probe.tscn -- --case=passive
## Cases: load, passive, flee, cower, grudge, taurock, souls, house, respawn. The world is the product; the probe
## only places a Druid slot 1 (Hunter) and kills what a case needs killed (Health.damage), like the playtests do.

const ORDERS := preload("res://scenes/units/unit_orders.gd")
const TAG := "PT73 "
const NTTS := "res://assets/original/maps/high_noon/ntts.json"  ## tool input only; the game reads the layout scene

var _world: Node3D
var _args: Dictionary = {}
var _out: Dictionary = {}


func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	var rules := (load("res://debug/rules/village.tres") as VillageRules).duplicate() as VillageRules
	rules.pause_npcs = false
	rules.match_seed = int(_args.get("seed", 73))
	_world = (load("res://scenes/match/high_noon.tscn") as PackedScene).instantiate()
	_world.set("rules", rules)
	add_child(_world)
	_run.call_deferred()


func _run() -> void:
	await _ticks(8)
	var name := str(_args.get("case", "load"))
	match name:
		"load": await _case_load()
		"passive": await _case_passive()
		"flee": await _case_flee()
		"cower": await _case_cower()
		"grudge": await _case_grudge()
		"taurock": await _case_taurock()
		"souls": await _case_souls()
		"house": await _case_house()
		"respawn": await _case_respawn()
		"ground": _case_ground()
		"taurockfight": await _case_taurockfight()
		"convert": await _case_convert()
		"cowerkill": await _case_cowerkill()
		_: _out["error"] = "caso desconocido %s" % name
	_out["case"] = name
	print(TAG + JSON.stringify(_out))
	get_tree().quit()


func _ticks(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _units() -> Node:
	return _world.get_node("%Units")


func _npc(label: String) -> UnitBody:
	return _units().get_node_or_null(label) as UnitBody


func _hunter(at: Vector3) -> UnitBody:
	var ground := float(GroundSurface.of(_world).height_at(at.x, at.z))
	var unit: UnitBody = _world.get_node("UnitSpawner").call("spawn_unit", {
		"tag": "nmuh", "label": "Druid", "slot": 1, "x": at.x, "y": (0.0 if is_nan(ground) else ground) + 0.2, "z": at.z, "yaw": 0.0})
	unit.name = "Hunter"
	unit.idle_aggro = false
	return unit


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _attack(hunter: UnitBody, target: Node3D) -> void:
	hunter.get_node("Orders").call("give", ORDERS.Command.ATTACK, target, target.global_position, Vector2.ZERO, 0.0)


func _farmers() -> Array[UnitBody]:
	var out: Array[UnitBody] = []
	for node in get_tree().get_nodes_in_group("npc"):
		var body := node as UnitBody
		if body != null and body.creature_tag == "zepe":
			out.append(body)
	return out


# --- cases ---

func _case_load() -> void:
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NTTS))
	var population: Dictionary = _world.get_node("%Population").get("report")
	_out["report"] = population
	var worst := 0.0
	var farmer_i := 0
	var taurock_i := 0
	var missing := []
	for row: Dictionary in rows["creatures"]:
		var label := ""
		if row["tag"] == "zepe":
			farmer_i += 1
			label = "Farmer%d" % farmer_i
		else:
			taurock_i += 1
			label = "Taurock%d" % taurock_i
		var body := _npc(label)
		if body == null:
			missing.append(label)
			continue
		worst = maxf(worst, _flat(body.global_position, Vector3(float(row["x"]), 0.0, float(row["z"]))))
		if body.owner_slot != SideRelations.slot_of(int(row["side"])):
			missing.append(label + " slot")
	_out["npc_max_error_m"] = snappedf(worst, 0.001)
	_out["npc_missing"] = missing
	_out["farmers"] = _farmers().size()
	var building_error := 0.0
	var index := 0
	var placed := 0
	var inside := []
	var shapes := []
	for row: Dictionary in rows["structures"]:
		index += 1
		if ["jfnt", "jaal"].has(str(row["tag"])):
			continue
		var node := _building_at(row)
		if node == null:
			missing.append("%s#%03d" % [row["tag"], index])
			continue
		placed += 1
		building_error = maxf(building_error, _flat(node.global_position, Vector3(float(row["x"]), 0.0, float(row["z"]))))
		if not node.collision.disabled:
			shapes.append(node)
	_out["buildings_found"] = placed
	_out["building_max_error_m"] = snappedf(building_error, 0.001)
	_out["shelter_group"] = get_tree().get_nodes_in_group("shelter").size()
	for npc in get_tree().get_nodes_in_group("npc"):
		for shape_owner: MapBuilding in shapes:
			var local := shape_owner.collision.global_transform.affine_inverse() * (npc as Node3D).global_position
			var half := (shape_owner.collision.shape as BoxShape3D).size * 0.5
			if absf(local.x) <= half.x and absf(local.z) <= half.z and absf(local.y) <= half.y + 3.0:
				inside.append("%s en %s" % [npc.name, shape_owner.name])
	_out["npc_inside_building"] = inside
	_out["npc_health"] = [_npc("Farmer1").type.health, _npc("Taurock1").type.health]
	_out["farmer_speed"] = _npc("Farmer1").move_speed
	_out["buildings_with_collision"] = shapes.size()


func _case_passive() -> void:
	var farmer := _npc("Farmer3")
	var hunter := _hunter(farmer.global_position + Vector3(4.0, 0.0, 0.0))
	var strikes := [0]
	for npc in get_tree().get_nodes_in_group("npc"):
		(npc as UnitBody).struck.connect(func(_t: Node3D, _a: float, _c: float, _r: float) -> void: strikes[0] += 1)
	var hunter_hits := [0]
	hunter.struck.connect(func(_t: Node3D, _a: float, _c: float, _r: float) -> void: hunter_hits[0] += 1)
	_attack(hunter, farmer)
	var modes := {}
	for _tick in 7200:
		await get_tree().physics_frame
		for npc in get_tree().get_nodes_in_group("npc"):
			var key := String(UnitBody.Mode.keys()[(npc as UnitBody).mode])
			modes[key] = int(modes.get(key, 0)) + 1
	_out["npc_strikes_120s"] = strikes[0]
	_out["hunter_hits"] = hunter_hits[0]
	_out["farmer3_health"] = [farmer.get_node("Health").get("current"), farmer.get_node("Health").get("maximum")]
	_out["farmers_alive"] = _farmers().filter(func(f: UnitBody) -> bool: return not f.is_dead()).size()
	_out["npc_mode_ticks"] = modes


func _case_flee() -> void:
	var farmer := _npc("Farmer3")
	var behavior := farmer.get_node("PeasantBehavior") as PeasantBehavior
	var shelter := behavior.closest_shelter()
	_out["shelter"] = shelter.name if shelter else "-"
	_out["shelter_m"] = snappedf(_flat(shelter.global_position, farmer.global_position), 0.1) if shelter else -1
	await _ticks(60)
	var start := farmer.global_position
	var hunter := _hunter(start + Vector3(-30.0, 0.0, 0.0))
	_out["hunter_m"] = snappedf(_flat(hunter.global_position, start), 0.1)
	var last := farmer.global_position
	var top := 0.0
	var moving_ticks := 0
	var moved := 0.0
	var at3 := 0.0
	for tick in 240:
		await get_tree().physics_frame
		var now := farmer.global_position
		var step := _flat(now, last) * 60.0
		if farmer.mode == UnitBody.Mode.MOVE and step > 0.1:
			moving_ticks += 1
			moved += step
			top = maxf(top, step)
		last = now
		if tick == 179:
			at3 = _flat(now, start)
	_out["moved_3s_m"] = snappedf(at3, 0.01)
	_out["moved_4s_m"] = snappedf(_flat(farmer.global_position, start), 0.01)
	_out["speed_mean_ms"] = snappedf(moved / maxf(moving_ticks, 1), 0.01)
	_out["speed_max_ms"] = snappedf(top, 0.01)
	_out["state"] = String(behavior.state)


func _case_cower() -> void:
	var farmer := _npc("Farmer6")
	await _ticks(30)
	var start := farmer.global_position
	_out["mode_1s"] = String(UnitBody.Mode.keys()[farmer.mode])
	var worst := 0.0
	for _tick in 600:
		await get_tree().physics_frame
		worst = maxf(worst, _flat(farmer.global_position, start))
	_out["mode_10s"] = String(UnitBody.Mode.keys()[farmer.mode])
	_out["moved_10s_m"] = snappedf(worst, 0.001)
	_out["cowering_total"] = get_tree().get_nodes_in_group("npc").filter(func(n: Node) -> bool: return (n as UnitBody).mode == UnitBody.Mode.COWER).size()


func _case_grudge() -> void:
	var farmer := _npc("Farmer3")
	var hunter := _hunter(farmer.global_position + Vector3(3.0, 0.0, 0.0))
	await _ticks(60)
	var first := [-1]
	var ticks := [0]
	hunter.struck.connect(func(_t: Node3D, _a: float, _c: float, _r: float) -> void:
		if first[0] < 0:
			first[0] = ticks[0])
	_attack(hunter, farmer)
	var herd: Array[UnitBody] = []
	var anchor := Vector3.ZERO
	var all_at := -1
	var last_gap := 0
	for tick in 1200:
		await get_tree().physics_frame
		ticks[0] += 1
		if first[0] >= 0 and herd.is_empty():
			anchor = farmer.global_position
			for other in _farmers():
				if other != farmer and _flat(other.global_position, anchor) <= 80.0:
					herd.append(other)
		if first[0] >= 0 and all_at < 0 and not herd.is_empty():
			var all := true
			for other in herd:
				all = all and (other.get_node("PeasantBehavior").grudge as GrudgeMemory).has_grudge(1)
			if all:
				all_at = ticks[0]
		if all_at >= 0:
			break
	_out["first_hit_tick"] = first[0]
	_out["herd_size"] = herd.size()
	_out["all_grudge_tick"] = all_at
	_out["delay_s"] = snappedf(float(all_at - first[0]) / 60.0, 0.001) if all_at >= 0 else -1.0
	var far_with := 0
	for other in _farmers():
		if other != farmer and _flat(other.global_position, anchor) > 80.0 and (other.get_node("PeasantBehavior").grudge as GrudgeMemory).has_grudge(1):
			far_with += 1
	_out["beyond_80m_with_grudge_at_that_moment"] = far_with


func _case_taurock() -> void:
	for farmer in _farmers():
		farmer.queue_free()
	await _ticks(4)
	var hunter := _hunter(Vector3(1270.0, 0.0, 1330.0))
	hunter.set("rng_seed", 9)
	var taurock := _npc("Taurock1")
	for gap in [80.0, 70.0]:
		hunter.get_node("Health").call("setup", 960.0)
		var at := _ground_spot(hunter.global_position, gap)
		taurock.warp_to(at)
		taurock.halt()
		var strikes := [0]
		var cb := func(_t: Node3D, _a: float, _c: float, _r: float) -> void: strikes[0] += 1
		taurock.struck.connect(cb)
		var target_tick := -1
		var strike_tick := -1
		for tick in 1200:
			await get_tree().physics_frame
			if target_tick < 0 and taurock.target == hunter:
				target_tick = tick
			if strike_tick < 0 and strikes[0] > 0:
				strike_tick = tick
			if strike_tick >= 0:
				break
		taurock.struck.disconnect(cb)
		_out["gap_%d" % int(gap)] = {"target_s": snappedf(float(target_tick) / 60.0, 0.01) if target_tick >= 0 else -1.0,
			"strike_s": snappedf(float(strike_tick) / 60.0, 0.01) if strike_tick >= 0 else -1.0, "distance_end": snappedf(_flat(taurock.global_position, hunter.global_position), 0.1)}
		hunter.global_position = Vector3(1270.0, hunter.global_position.y, 1330.0)
		taurock.warp_to(_ground_spot(Vector3(1500.0, 0.0, 1100.0), 0.0))
		await _ticks(30)


## A point `gap` meters from `origin` on the land: the first of eight directions whose point has ground.
func _ground_spot(origin: Vector3, gap: float) -> Vector3:
	var terrain := GroundSurface.of(_world)
	for k in 8:
		var angle := TAU * k / 8.0
		var at := origin + Vector3(cos(angle), 0.0, sin(angle)) * gap
		if terrain.is_on_ground(at.x, at.z):
			at.y = float(terrain.height_at(at.x, at.z))
			return at
	return origin


func _case_souls() -> void:
	var soul_system := _world.get_node("SoulSystem")
	var wizard := get_tree().get_first_node_in_group("wizard") as Node3D
	var farmer := _npc("Farmer3")
	var taurock := _npc("Taurock2")
	var seen := []
	soul_system.connect("soul_spawned", func(soul: Node3D) -> void: seen.append(soul))
	farmer.get_node("Health").call("damage", 9999.0, 1)
	taurock.get_node("Health").call("damage", 9999.0, 1)
	await _ticks(240)
	var report := []
	for soul: Soul in seen:
		report.append({"n": soul.number, "slot": soul.owner_slot, "red_for_1": soul.color_for(1) == Soul.SoulColor.RED,
			"red_for_2": soul.color_for(2) == Soul.SoulColor.RED, "attached": soul.attached, "origin": String(soul.origin)})
	_out["souls"] = report
	var purse := wizard.get_node("SoulPurse")
	_out["purse_before"] = purse.get("count")
	if not seen.is_empty():
		var soul: Soul = seen[0]
		wizard.global_position = soul.global_position
		wizard.set("velocity", Vector3.ZERO)
		await _ticks(600)
		_out["purse_after_10s_on_top"] = purse.get("count")
		_out["soul_still_there"] = is_instance_valid(soul) and soul.state == Soul.State.NORMAL


func _case_house() -> void:
	var hut: MapBuilding = null
	for node in get_tree().get_nodes_in_group("shelter"):
		if _flat((node as Node3D).global_position, Vector3(1255.0, 0.0, 1214.0)) < 3.0:
			hut = node as MapBuilding
	var hunter := _hunter(hut.global_position + Vector3(0.0, 0.0, -14.0))
	var souls_before := get_tree().get_nodes_in_group("soul").size()
	var info := {"health": [hut.health.current, hut.health.maximum], "shelter": hut.shelter}
	_attack(hunter, hut)
	var tick := 0
	while not hut.is_destroyed() and tick < 120 * 60 * 5:
		await get_tree().physics_frame
		tick += 1
	info["destroyed"] = hut.is_destroyed()
	info["seconds"] = snappedf(float(tick) / 60.0, 0.1)
	info["souls_new"] = get_tree().get_nodes_in_group("soul").size() - souls_before
	info["shelter_group_after"] = get_tree().get_nodes_in_group("shelter").size()
	_out["hut"] = info
	var any_wall: MapBuilding = null
	for node in get_tree().get_nodes_in_group("map_building"):
		if (node as MapBuilding).tag == "bld1":
			any_wall = node
			break
	if any_wall != null:
		var hunter2 := _hunter(any_wall.global_position + Vector3(0.0, 0.0, -14.0))
		_attack(hunter2, any_wall)
		await _ticks(1200)
		_out["wall"] = {"max_health": any_wall.max_health, "indestructible": any_wall.is_indestructible(), "destroyed": any_wall.is_destroyed()}
	_out["wall_node"] = str(any_wall)


func _case_ground() -> void:
	var terrain := GroundSurface.of(_world)
	var out := []
	for z in [1060, 1080, 1100, 1120, 1140]:
		for x in [1000, 1030, 1060, 1090, 1120]:
			out.append([x, z, terrain.is_on_ground(x, z), snappedf(float(terrain.height_at(x, z)), 0.1)])
	_out["grid"] = out
	var start := _world.get_node("Map/MapProps/Starts/Start1")
	_out["start1"] = [start.global_position.x, start.global_position.y, start.global_position.z]
	var altar := start.get_node_or_null("Altar")
	_out["altar_children"] = start.get_children().map(func(n: Node) -> String: return n.name)
	if altar:
		_out["altar_at"] = [altar.global_position.x, altar.global_position.z]


func _case_cowerkill() -> void:
	var farmer := _npc("Farmer6")
	var hunter := _hunter(farmer.global_position + Vector3(15.0, 0.0, 0.0))
	_attack(hunter, farmer)
	var trace := []
	for sec in 40:
		await _ticks(60)
		trace.append([sec + 1, snappedf(hunter.global_position.x, 0.1), snappedf(hunter.global_position.z, 0.1), UnitBody.Mode.keys()[hunter.mode], snappedf(float(farmer.get_node("Health").get("current")), 1.0), snappedf(_flat(hunter.global_position, farmer.global_position), 0.1)])
	_out["trace"] = trace


## Convert of a Farmer's soul and of a Taurock's, without the UI: the cast of the Caster is what the action does
## (begin_convert_cast, then finish_cast when the casting time is over). The ledger of AiAudit is read at the end.
func _case_convert() -> void:
	var system := _world.get_node("SacrificeSystem") as SacrificeSystem
	var soul_system := _world.get_node("SoulSystem")
	var wizard := get_tree().get_first_node_in_group("wizard") as WizardBody
	var purse := wizard.get_node("SoulPurse")
	var audit := AiAudit.new()
	add_child(audit)
	audit.watch_purse(1, purse)
	audit.watch_sources(soul_system, system)
	audit.start()
	var seen := []
	soul_system.connect("soul_spawned", func(soul: Node3D) -> void: seen.append(soul))
	## Both stand 45 m from the altar of slot 1 before they die, as in debug/convert_ritual.
	for pair in [["Farmer3", Vector3(1507.0, 0.0, 1525.0)], ["Taurock2", Vector3(1480.0, 0.0, 1520.0)]]:
		var body := _npc(pair[0])
		var spot: Vector3 = pair[1]
		spot.y = float(GroundSurface.of(_world).height_at(spot.x, spot.z))
		body.warp_to(spot)
		body.get_node("Health").call("damage", 9999.0, 1)
	await _ticks(300)
	var results := []
	var first_two: Array = seen.slice(0, 2)
	_out["souls_seen"] = seen.size()
	for soul: Soul in first_two:
		var before := int(purse.get("count"))
		var count: int = soul.number
		var status := system.convert_status(1, soul)
		var cast := system.begin_convert_cast(wizard, soul, 2.0)
		await _ticks(120)
		var problem := system.finish_cast(cast)
		print("PT73_PROGRESS convert soul=%d status='%s' problem='%s'" % [count, status, problem])
		var ticks := 0
		while int(purse.get("count")) == before and ticks < 60 * 150:
			await get_tree().physics_frame
			ticks += 1
		results.append({"souls": count, "status": status, "problem": problem, "gain": int(purse.get("count")) - before, "seconds_after_cast": snappedf(float(ticks) / 60.0, 0.1)})
	_out["converts"] = results
	_out["ledger"] = audit.sides_report().get("1", {}).get("souls_ledger", {})
	_out["purse"] = purse.get("count")


func _case_taurockfight() -> void:
	for farmer in _farmers():
		farmer.queue_free()
	await _ticks(4)
	var hunter := _hunter(Vector3(1270.0, 0.0, 1330.0))
	var taurock := _npc("Taurock1")
	taurock.warp_to(_ground_spot(hunter.global_position, 20.0))
	if _args.has("still"):
		taurock.process_mode = Node.PROCESS_MODE_DISABLED
	_attack(hunter, taurock)
	var trace := []
	for sec in 30:
		await _ticks(60)
		var melee := hunter.weapons.melee
		trace.append([sec + 1, snappedf(_flat(hunter.global_position, taurock.global_position), 0.1), UnitBody.Mode.keys()[hunter.mode], UnitBody.Mode.keys()[taurock.mode], snappedf(float(taurock.get_node("Health").get("current")), 1.0), snappedf(float(hunter.get_node("Health").get("current")), 1.0), melee.in_reach(taurock, 0.8), str(MeleeRules.profile_of(taurock))])
	_out["trace"] = trace


func _case_respawn() -> void:
	for farmer in _farmers():
		farmer.get_node("Health").call("damage", 9999.0, 1)
	await _ticks(600 * 60)
	var alive := 0
	var total := 0
	for node in get_tree().get_nodes_in_group("npc"):
		var body := node as UnitBody
		if body.creature_tag == "zepe":
			total += 1
			if not body.is_dead():
				alive += 1
	var audit_like := 0
	for node in _units().get_children():
		if (node as UnitBody).creature_tag == "zepe" and not (node as UnitBody).is_dead():
			audit_like += 1
	_out["farmers_alive_10min"] = alive
	_out["farmers_nodes_in_group"] = total
	_out["farmers_alive_under_units"] = audit_like
	_out["units_children"] = _units().get_child_count()


static func _parse(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in raw:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out


## The MapBuilding of the map that stands on an NTTS row (same tag, within a meter on the ground).
func _building_at(row: Dictionary) -> MapBuilding:
	for node in get_tree().get_nodes_in_group(MapBuilding.GROUP):
		var building := node as MapBuilding
		if building.tag == str(row["tag"]) and _flat(building.global_position, Vector3(float(row["x"]), 0.0, float(row["z"]))) < 1.0:
			return building
	return null
