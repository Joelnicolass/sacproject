extends RefCounted

## RFC-024 024c cases of rules_suite: the pure accounts of the AI (AiRand, AiRater, AiField, the cast queue) against numbers worked
## out by hand from `sacengine/source/bots/shiny.d` (each case says the lines), and the contract of the port: the AI's only way out
## of itself is AiCommandPort, and what it orders through Orders.apply_for is checked for its owner like a human's.
## The values were computed apart from the GDScript, with the formulas of the D file written again in float32 arithmetic
## (Python struct round trips), so a slip in the port does not copy into the expectation.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const ORDERS_SCRIPT := preload("res://scenes/orders/orders.gd")
const UnitOrders := preload("res://scenes/units/unit_orders.gd")
const RULES := preload("res://data/match_rules.tres")
const TOL := 0.0005
const AI_DIR := "res://scenes/ai"


func run(host: Node3D) -> Dictionary:
	var out := {}
	out["ai_rand_msvc"] = _rand()
	out["ai_rater_stats"] = _rater_stats()
	out["ai_rater_ability"] = _rater_ability()
	out["ai_rater_combine"] = _rater_combine()
	out["ai_field_ramp"] = _field_ramp()
	out["ai_field_weights"] = _field_weights()
	out["ai_field_groups"] = _field_groups()
	out["ai_cast_queue"] = _cast_queue()
	out["ai_profile_original"] = _profile()
	out["ai_port_only_exit"] = _only_exit()
	out["ai_apply_for_owner"] = await _apply_for(host)
	out["ai_guard_no_nan"] = _no_nan()
	out["nav_rebuild_structure"] = await _nav_rebuild(host)
	out["ai_spell_eval_support"] = _spell_eval()
	out["ai_capture_territory"] = _territory()
	out["doctor_carrier_follows_path"] = _doctor_wiring()
	out["nav_box_blockers"] = _box_blockers()
	out["ai_difficulty_files"] = _difficulties()
	out["ai_profiles_by_god"] = _profiles_by_god()
	out["ai_limited_information"] = await _limited_information(host)
	out["ai_convert_reserved_soul"] = _reserved_soul()
	out["ai_forget_checked"] = await _forget_checked(host)
	out["ai_own_splash"] = await _own_splash(host)
	out["ai_tactics_by_difficulty"] = _tactics()
	out["ai_heal_threshold"] = await _heal_threshold(host)
	out["ai_kill_estimate"] = _kill_estimate()
	return out


static func _near(a: float, b: float, tol := TOL) -> bool:
	return absf(a - b) <= tol * maxf(1.0, absf(b))


static func _verdict(checks: Dictionary, detail := {}) -> Dictionary:
	var ok := true
	for key in checks:
		if not bool(checks[key]):
			ok = false
	var out := {"ok": ok}
	if not ok:
		out["checks"] = checks
		out["detail"] = detail
	return out


## shiny.d:31-38. The first values of rand() from state 1 are the well known 41, 18467, 6334, 26500, 19169, 15724, 11478,
## 29358, 26962, 24464 (MSVCRT); seed 12345 gives 7584, 19164, 25795, 22125, 5828 (state*214013+2531011, bits 16..30).
func _rand() -> Dictionary:
	var rng := AiRand.new()
	var first: Array[int] = []
	for i in 10:
		first.append(rng.next())
	var seeded := AiRand.with_seed(12345)
	var second: Array[int] = []
	for i in 5:
		second.append(seeded.next())
	var unit := AiRand.new()
	var u := unit.unit()
	return _verdict({
		"state1": first == [41, 18467, 6334, 26500, 19169, 15724, 11478, 29358, 26962, 24464],
		"seed12345": second == [7584, 19164, 25795, 22125, 5828],
		"unit": _near(u, 41.0 * 3.0518509447574615e-05),
		"same_seed_same": AiRand.with_seed(7).next() == AiRand.with_seed(7).next(),
	}, {"first": first, "second": second})


## Trogg (ycro) as the rater reads it (shiny.d:251-262 fillStats, 214-220 rate): strength 200, accuracy 1000, evasion 1100,
## run 825, health 960, regeneration 1000, resistances 1000 and 900:
##   [0] 200*(1000*0.001) = 200; [2] 1000/1000 * f32(f32(1.1)*960*1.0) = 1056; [3] 1000/900 * 1056 = 1173.3334; [4] 0.825
##   rate = (1173.3334 + 1056)*0.5 + 2*(0 + 200) = 1514.6667.
func _rater_stats() -> Dictionary:
	var type := GameData.creature("ycro")
	var acc := AiRater.fill_by_tag(type, [])
	return _verdict({
		"melee": _near(acc[0], 200.0),
		"ability": _near(acc[1], 0.0),
		"health_melee": _near(acc[2], 1056.0),
		"health_ranged": _near(acc[3], 1173.3333740234375),
		"speed": _near(acc[4], 0.824999988079071),
		"rate": _near(AiRater.rate(acc), 1514.666748046875),
	}, {"acc": acc, "rate": AiRater.rate(acc)})


## Earthfling (palk), by tag (shiny.d:265-281, abilityAcc 243-249): strength 90, accuracy 800, evasion 880, run 900, health 960,
## melee resistance 4000, mana 200, ranged accuracy 600; its 'ekba' (amount2 120, range 75, cost 5) adds
## 800*0.001*120 * (600*0.001*75*(1 - 5/200)) * 0.04 = 168.48; 'dihk' (amount2 0) adds nothing. A flier (Gargoyle sohe: fly 1125, ranged
## resistance 2000) has its melee health x4 and k = 1/980: [2] = 4 * 1000/1000 * 687.5 = 2750, [1] = 152.8163.
func _rater_ability() -> Dictionary:
	var palk := GameData.creature("palk")
	var abilities: Array = []
	abilities.assign(palk.abilities())
	var by_tag := AiRater.fill_by_tag(palk, abilities)
	var gargoyle := GameData.creature("sohe")
	var g_abilities: Array = []
	g_abilities.assign(gargoyle.abilities())
	var garg := AiRater.fill_by_tag(gargoyle, g_abilities)
	## fillFromObject with 100 mana: the ability is cheaper to afford... f = 5/100: 164.16.
	var live := AiRater.fill_from_object(AiRater.stats_of(palk), 100, abilities, [])
	return _verdict({
		"palk_melee": _near(by_tag[0], 72.0),
		"palk_ability": _near(by_tag[1], 168.47999572753906),
		"palk_health_melee": _near(by_tag[2], 211.1999969482422),
		"palk_health_ranged": _near(by_tag[3], 844.7999877929688),
		"palk_rate": _near(AiRater.rate(by_tag), 1008.9599609375),
		"palk_live_mana100": _near(live[1], 164.16000366210938),
		"garg_ability": _near(garg[1], 152.8163299560547),
		"garg_health_melee": _near(garg[2], 2750.0),
		"garg_speed": _near(garg[4], 1.125),
		"garg_rate": _near(AiRater.rate(garg), 2002.5076904296875),
	}, {"palk": by_tag, "garg": garg, "live": live})


## combine (shiny.d:207-209: a = wB*b + wA*a), divide (210-213: elements 0..3), rateWithBase (221-229). With trogg = [200, 0, 1056, 1173.33, 0.825]
## and palk = [72, 168.48, 211.2, 844.8, 0.9]: trogg against palk = max(200-21.12,0) + max(0-84.48,0) - (max(168.48-117.33,0) +
## max(72-105.6,0)) + (0.825-0.9)*10 = 178.88 - 51.147 - 0.75 = 126.9833; palk against trogg = -126.9833.
func _rater_combine() -> Dictionary:
	var trogg := AiRater.fill_by_tag(GameData.creature("ycro"), [])
	var palk_type := GameData.creature("palk")
	var abilities: Array = []
	abilities.assign(palk_type.abilities())
	var palk := AiRater.fill_by_tag(palk_type, abilities)
	var mixed := AiRater.new_acc()
	AiRater.combine(mixed, 1.0, trogg, 1.0)
	AiRater.combine(mixed, 1.0, palk, 0.5)
	var divided := mixed.duplicate()
	AiRater.divide(divided, 4.0)
	var untouched := mixed.duplicate()
	AiRater.divide(untouched, 0.0)
	return _verdict({
		"combine_0": _near(mixed[0], 236.0),
		"combine_1": _near(mixed[1], 84.23999786376953),
		"combine_2": _near(mixed[2], 1161.5999755859375),
		"combine_3": _near(mixed[3], 1595.7333984375),
		"combine_4": _near(mixed[4], 1.274999976158142),
		"divide_0": _near(divided[0], 59.0),
		"divide_3": _near(divided[3], 398.933349609375),
		"divide_speed_kept": _near(divided[4], 1.274999976158142),
		"divide_zero_noop": _near(untouched[0], 236.0),
		"with_base_trogg_palk": _near(AiRater.rate_with_base(trogg, palk), 126.98334503173828),
		"with_base_palk_trogg": _near(AiRater.rate_with_base(palk, trogg), -126.98334503173828),
	}, {"mixed": mixed})


## The falloff of probOr/densityGroups/influenceGroups (shiny.d:2012-2082): 1 up to near, 0 from far, (far-d)/(far-near).
## near 10, far 3620: d=130 -> 0.96676, d=5 -> 1, d=4000 -> 0, d=1815 -> 0.5. probOr over 130 m and 658 m: w1² = 0.93461, then
## acc = 0.93461 + w2²(1 - 0.93461) = 0.97864.
func _field_ramp() -> Dictionary:
	var prob := AiField.prob_or(PackedFloat32Array([130.0, 658.0]), 10.0, 3620.0)
	return _verdict({
		"d130": _near(AiField.ramp(130.0, 10.0, 3620.0), 0.9667590260505676),
		"near": _near(AiField.ramp(5.0, 10.0, 3620.0), 1.0),
		"far": _near(AiField.ramp(4000.0, 10.0, 3620.0), 0.0),
		"half": _near(AiField.ramp(1815.0, 10.0, 3620.0), 0.5),
		"prob_or": _near(prob, 0.9786359667778015),
		"prob_or_empty": AiField.prob_or(PackedFloat32Array(), 10.0, 3620.0) == 0.0,
		"lerp": _near(AiField.lerp_w(0.4, 0.5, 0.2), 0.3),
	}, {"prob": prob})


## weightTriple (shiny.d:2953-2966): ratio 0.5, aggression 1: guard -> o = [1/12 -> 0.0769231, 0.4615385, 0.4615385];
## capture -> [0.2727273, 0.1818182, 0.5454546]; ratio 1.0 -> [1/7, 6/7, 0]; focus (and idle) -> 0.3333 each.
## wizAttack weight (3052-3072): d <= 10 -> 1; d=145, thr=280 -> 0.5; x0.5 not a wizard; x1/3 not ready; x10 Sac Doctor.
func _field_weights() -> Dictionary:
	var w0 := AiField.weight_triple(AiTask.Kind.GUARD, 0.5, 1.0)
	var w2 := AiField.weight_triple(AiTask.Kind.CAPTURE, 0.5, 1.0)
	var w1 := AiField.weight_triple(AiTask.Kind.GUARD, 1.0, 1.0)
	var w3 := AiField.weight_triple(AiTask.Kind.FOCUS, 0.5, 1.0)
	## the tracks the old status words 1 (a creature that fights), 0x2000e (a wizard) and 0x1001 (a ready Manahoar that fights) were
	var fighter := AiTrack.new()
	fighter.kind = AiTrack.Kind.CREATURE
	fighter.fights = true
	var wizard := AiTrack.new()
	wizard.kind = AiTrack.Kind.WIZARD
	var channeler := AiTrack.new()
	channeler.kind = AiTrack.Kind.MANAHOAR
	channeler.fights = true
	channeler.ready = true
	return _verdict({
		"cmd0": _near(w0[0], 0.07692307978868484) and _near(w0[1], 0.4615384638309479) and _near(w0[2], 0.4615384638309479),
		"cmd2": _near(w2[0], 0.27272728085517883) and _near(w2[1], 0.1818181872367859) and _near(w2[2], 0.5454545617103577),
		"ratio1": _near(w1[0], 0.1428571492433548) and _near(w1[1], 0.8571428656578064) and _near(w1[2], 0.0),
		"cmd3_default": _near(w3[0], 0.3333) and _near(w3[2], 0.3333),
		"attack_near": _near(AiField.attack_weight(5.0, 280.0, fighter), 0.1666666716337204),
		"attack_wizard_status": _near(AiField.attack_weight(145.0, 280.0, wizard), 0.1666666716337204),
		"attack_creature": _near(AiField.attack_weight(145.0, 280.0, fighter), 0.0833333358168602),
		"attack_out": AiField.attack_weight(300.0, 280.0, fighter) == 0.0,
		"attack_doctor": _near(AiField.attack_weight(50.0, 280.0, channeler, true), 4.2592592592592595),
		"reach": _near(AiField.attack_reach(0.2, 280.0), 224.0),
		"summon_pos": _near(AiField.summon_score(100.0, 300, 1000), 70.0),
		"summon_neg": _near(AiField.summon_score(-100.0, 300, 1000), -30.0),
		"cost_scaled": _near(AiField.spell_cost_scaled(10.0, 300, 1000), 7.0) and _near(AiField.spell_cost_scaled(10.0, 300, 0), 10.0),
	}, {"w0": w0, "w2": w2, "w1": w1})


## canAccept (shiny.d:1702-1710): the radius is 30 * min(1 + 0.1n, 1.8): n=0 -> 30, 1 -> 33, 2 -> 36, 8 and beyond -> 54.
func _field_groups() -> Dictionary:
	return _verdict({
		"r0": _near(AiField.group_radius(0), 30.0),
		"r1": _near(AiField.group_radius(1), 33.0),
		"r2": _near(AiField.group_radius(2), 36.0),
		"r8": _near(AiField.group_radius(8), 54.0),
		"r20": _near(AiField.group_radius(20), 54.0),
		"accept_inside": AiField.can_accept(2, 35.9 * 35.9),
		"accept_edge": AiField.can_accept(2, 36.0 * 36.0),
		"reject_outside": not AiField.can_accept(2, 36.1 * 36.1),
	})


## enqueueCast (shiny.d:2638-2662): forced entries first, then by score, best first; a new entry goes before its ties; the same
## spell tag replaces the old entry.
func _cast_queue() -> Dictionary:
	var a := SpellType.new()
	a.tag = "aaaa"
	var b := SpellType.new()
	b.tag = "bbbb"
	var c := SpellType.new()
	c.tag = "cccc"
	var d := SpellType.new()
	d.tag = "dddd"
	var queue: Array = []
	AiCastQueue.enqueue(queue, AiCastQueue.make(0, 1.0, null, a, 10.0, null))
	AiCastQueue.enqueue(queue, AiCastQueue.make(0, 3.0, null, b, 10.0, null))
	AiCastQueue.enqueue(queue, AiCastQueue.make(AiCastQueue.FORCED, 0.0, null, c, 10.0, null))
	AiCastQueue.enqueue(queue, AiCastQueue.make(0, 3.0, null, d, 10.0, null))
	var order: Array[String] = []
	for entry: Dictionary in queue:
		order.append(str((entry["spell"] as SpellType).tag))
	AiCastQueue.enqueue(queue, AiCastQueue.make(0, 5.0, null, a, 10.0, null))
	var again: Array[String] = []
	for entry: Dictionary in queue:
		again.append(str((entry["spell"] as SpellType).tag))
	return _verdict({
		"forced_then_score_ties_before": order == ["cccc", "dddd", "bbbb", "aaaa"],
		"same_tag_replaced": again == ["cccc", "aaaa", "dddd", "bbbb"] and queue.size() == 4,
	}, {"order": order, "again": again})


## The numbers of profile_original.tres are the ones of the commercial version (every beta* off): slots 12/60/6/6/60/12, aggression 1,
## attack coefficient 280, summon cap 0.6, group radius 30.
func _profile() -> Dictionary:
	var profile: AiProfile = load("res://data/ai/profile_original.tres")
	return _verdict({
		"loaded": profile != null,
		"periods": profile != null and profile.slot_periods == PackedInt32Array([12, 60, 6, 6, 60, 12]),
		"aggression": profile != null and profile.aggression == 1.0,
		"attack": profile != null and profile.attack_coefficient == 280.0,
		"summon_cap": profile != null and profile.summon_threat_cap == 0.6,
		"ready_divisor_retail": profile != null and profile.ready_divisor == 2,
		"emergency_ratio": profile != null and profile.emergency_mana_ratio == 1400.0,
	})


## RFC §3.2 and RULES.md: the AI leaves only through AiCommandPort. No script of the AI outside `command/` may call what changes the
## game (the Caster, the Orders, the wizard's walk, a pool or a purse) or open an RPC. Reads of those nodes are fine.
func _only_exit() -> Dictionary:
	var forbidden := ["request_cast", "request_summon", "request_structure", "apply_for", "request_walk", "begin_walk", "walk_to(", ".rpc(", "rpc_id", "@rpc", "\"spend\"", ".spend(", "\"take\"", "\"add\"", ".damage(", "queue_free", "set_multiplayer_authority"]
	var offenders: Array[String] = []
	var files := _scripts(AI_DIR)
	for path in files:
		if path.contains("/command/"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for number in lines.size():
			var line := lines[number]
			if line.strip_edges().begins_with("##") or line.strip_edges().begins_with("#"):
				continue
			for word in forbidden:
				if line.contains(word):
					offenders.append("%s:%d %s" % [path.get_file(), number + 1, word])
	return _verdict({"no_offenders": offenders.is_empty(), "scanned": files.size() > 10}, {"offenders": offenders, "files": files.size()})


static func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for name in dir.get_files():
		if name.ends_with(".gd"):
			found.append(dir_path.path_join(name))
	for sub in dir.get_directories():
		found.append_array(_scripts(dir_path.path_join(sub)))
	return found


## Orders.apply_for (RFC-024 §3.1): the AI orders with its slot, and _apply keeps the owner check of a human's order: of two units
## given to the slot 2, the one of slot 1 gets nothing. A slot of 0 does nothing.
func _apply_for(host: Node3D) -> Dictionary:
	var orders := Node.new()
	orders.set_script(ORDERS_SCRIPT)
	orders.name = "AiCasesOrders"
	host.add_child(orders)
	var mine := _unit(host, 2, Vector3(500.0, 0.0, 500.0))
	var theirs := _unit(host, 1, Vector3(520.0, 0.0, 500.0))
	await host.get_tree().process_frame
	orders.call("apply_for", 2, [mine, theirs], "move", Vector3(560.0, 0.0, 560.0), null)
	var mine_command := int(mine.get_node("Orders").get("command"))
	var theirs_command := int(theirs.get_node("Orders").get("command"))
	var nobody := _unit(host, 2, Vector3(540.0, 0.0, 500.0))
	orders.call("apply_for", 0, [nobody], "move", Vector3(560.0, 0.0, 560.0), null)
	var nobody_command := int(nobody.get_node("Orders").get("command"))
	for node: Node in [orders, mine, theirs, nobody]:
		node.queue_free()
	return _verdict({
		"own_unit_ordered": mine_command == UnitOrders.Command.MOVE,
		"foreign_unit_not": theirs_command == UnitOrders.Command.NONE,
		"slot_zero_nothing": nobody_command == UnitOrders.Command.NONE,
	}, {"mine": mine_command, "theirs": theirs_command, "nobody": nobody_command})


func _unit(host: Node3D, slot: int, at: Vector3) -> Node3D:
	var type := GameData.creature("ycro")
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = "AiCasesUnit%d_%d" % [slot, int(at.x)]
	unit.position = at
	unit.set("owner_slot", slot)
	unit.set("type", GameData.creature("ycro"))
	unit.set("model", type.model_id())
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	host.add_child(unit)
	return unit


## NavService (RFC-024 024c, the debt of F72/F73): a structure that appears under `structures` blocks the pathfinder after it is built again
## (once, two frames later), and when it leaves the spot is free again. On the navmesh (RFC-035 035i).
func _nav_rebuild(host: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "NavRebuildCases"
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	terrain.shape = GroundSurface.with_data(MapCatalog.active().terrain)
	terrain.add_child(terrain.shape)
	terrain.add_to_group(NavFingerprint.GROUP)
	root.add_child(terrain)
	var structures := Node3D.new()
	structures.name = "Structures"
	root.add_child(structures)
	var service := NavService.new()
	service.name = "Nav"
	service.ground = terrain.shape
	service.structures = structures
	service.build_on_ready = false
	root.add_child(service)
	host.add_child(root)
	terrain.add_child(terrain.make_collision_body())  # a Terrain from the script alone has no body
	if not terrain.shape.is_loaded():
		root.free()
		return {"ok": false, "reason": "sin terreno (assets/original/maps/high_noon/terrain.res)"}
	service.build()
	await _nav_settle(service, host)
	var spot := Vector3(1037.7, 15.0, 1009.9)
	var free_before := service.is_free_at(spot)
	var body := StaticBody3D.new()
	body.name = "FakeManalith"
	body.add_to_group(&"structure")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 4.0
	## Like structure.tscn: 8 m tall, centered 4 m up. A top within the agent's climb (3 m) would be walkable and connected.
	cylinder.height = 8.0
	shape.shape = cylinder
	shape.position = Vector3(0.0, 4.0, 0.0)
	body.add_child(shape)
	var ground: float = terrain.shape.height_at(spot.x, spot.z)
	body.position = spot if is_nan(ground) else Vector3(spot.x, ground, spot.z)
	structures.add_child(body)
	await _nav_settle(service, host)
	var blocked := not service.is_free_at(spot)
	var rebuilt_once := service.rebuilds == 1
	structures.remove_child(body)
	body.free()
	await _nav_settle(service, host)
	var free_again := service.is_free_at(spot)
	var rebuilt_twice := service.rebuilds == 2
	root.free()
	return _verdict({
		"free_before": free_before,
		"blocked_after_enter": blocked,
		"rebuilt_once": rebuilt_once,
		"free_after_exit": free_again,
		"rebuilt_twice": rebuilt_twice,
	})


## A few ticks, and with the navmesh backend until its re-bake is swapped in (bounded: the swap is a count of ticks).
func _nav_settle(service: NavService, host: Node3D) -> void:
	for _frame in 5:
		await host.get_tree().physics_frame
	var guard := 900
	while service.is_rebaking() and guard > 0:
		guard -= 1
		await host.get_tree().physics_frame
	for _frame in 3:
		await host.get_tree().physics_frame


## N3 of the review of 024c: with no souls seen (max 0) the density of the guard task is 0, not NaN (which made every guard
## score NaN and left the wizard with no escort).
func _no_nan() -> Dictionary:
	var board := AiTaskBoard.new()
	var perception := AiPerception.new()
	var groups := AiGroups.new()
	board.perception = perception
	board.groups = groups
	perception.max_souls_seen = 0
	var density := board.density(Vector3.ZERO, 10.0, 160.0)
	var out := _verdict({"zero": density == 0.0 and not is_nan(density)}, {"density": density})
	board.free()
	perception.free()
	groups.free()
	return out


## 024d: which evaluator each spell of the five books gets (shiny.d:334-345) and what each mask accepts: wizSupport (0xa4000000) takes
## Heal and Speedup, wizAttack (0x58000000) the attack of the god, and neither takes the other's.
func _spell_eval() -> Dictionary:
	var checks := {}
	var heal := GameData.spell("laeh")
	var speed := GameData.spell("pups")
	var rock := GameData.spell("kcor")
	var wrath := GameData.spell("oalf")
	checks["heal_fn"] = AiSpellEval.rating_fn(heal) == AiSpellEval.FN_HEAL
	checks["speedup_fn"] = AiSpellEval.rating_fn(speed) == AiSpellEval.FN_SPEEDUP
	checks["rock_single"] = AiSpellEval.rating_fn(rock) == AiSpellEval.FN_SINGLE
	checks["wrath_area"] = AiSpellEval.rating_fn(wrath) == AiSpellEval.FN_AREA
	checks["support_takes_heal_speedup"] = AiSpellEval.casts_in(heal, SpellType.AiPhase.SUPPORT) and AiSpellEval.casts_in(speed, SpellType.AiPhase.SUPPORT)
	checks["support_leaves_attack"] = not AiSpellEval.casts_in(rock, SpellType.AiPhase.SUPPORT) and not AiSpellEval.casts_in(wrath, SpellType.AiPhase.SUPPORT)
	checks["attack_leaves_support"] = AiSpellEval.casts_in(rock, SpellType.AiPhase.ATTACK) and not AiSpellEval.casts_in(heal, SpellType.AiPhase.ATTACK)
	checks["convert_none"] = AiSpellEval.rating_fn(GameData.spell("ccas")) == AiSpellEval.FN_NONE
	return _verdict(checks)


## territorialScore (shiny.d:2023-2041, by hand): one Manalith 500 m away weighs (1000-500)/(1000-10) = 0.50505; two of them add as
## probabilities: s²(1-acc)+acc -> 0.25508 then 0.25508 + 0.25508*(1-0.25508) = 0.44547; one on top of the point is 1.
func _territory() -> Dictionary:
	var task := CaptureTask.new()
	var board := AiTaskBoard.new()
	var perception := AiPerception.new()
	board.perception = perception
	task.board = board
	var checks := {}
	var make := func(at: Vector3, manalith: bool) -> AiTrack:
		var t := AiTrack.new()
		t.cur_pos = at
		t.kind = AiTrack.Kind.STRUCTURE
		t.site = AiTrack.Site.MANALITH if manalith else AiTrack.Site.ALTAR
		return t
	perception._structures[0].append(make.call(Vector3(500.0, 0.0, 0.0), true))
	checks["one_at_500"] = _near(task.territorial_score(Vector3.ZERO, null), 0.50505 * 0.50505, 0.001)
	perception._structures[0].append(make.call(Vector3(0.0, 0.0, 500.0), true))
	checks["two_add"] = _near(task.territorial_score(Vector3.ZERO, null), 0.25508 + 0.25508 * (1.0 - 0.25508), 0.001)
	checks["on_top"] = _near(task.territorial_score(Vector3(500.0, 0.0, 0.0), null), 1.0, 0.001)
	perception._structures[0].clear()
	perception._structures[0].append(make.call(Vector3(60.0, 0.0, 0.0), false))
	checks["altar_60m_nothing"] = task.territorial_score(Vector3.ZERO, null) == 0.0
	task.free()
	board.free()
	perception.free()
	return _verdict(checks)


## The carrier doctor has a PathFollower; the doctor of the ritual ring does not (it stands inside what the navmesh blocks).
func _doctor_wiring() -> Dictionary:
	var carrier := preload("res://scenes/sacrifice/carrier_doctor.tscn").instantiate()
	var ring := preload("res://scenes/sacrifice/ritual_doctor.tscn").instantiate()
	var checks := {
		"carrier_has_follower": carrier.get_node_or_null("PathFollower") != null,
		"ring_has_none": ring.get_node_or_null("PathFollower") == null,
	}
	carrier.free()
	ring.free()
	return _verdict(checks)


## NavBoxBlockers (RFC-035 035i; the land cache of the old grid went with it): a box is kept with its clearance, a line through it
## (or grazing it within the clearance) crosses, a line clear of it does not, and `reset` forgets the boxes.
func _box_blockers() -> Dictionary:
	var boxes := NavBoxBlockers.new()
	boxes.reset(0.5)
	boxes.add(Vector2(100.0, 100.0), Vector2(4.0, 4.0), 0.0)
	var checks := {
		"holds_box": not boxes.is_empty(),
		"through_crosses": boxes.crosses_box(Vector3(80.0, 0.0, 100.0), Vector3(120.0, 0.0, 100.0)),
		"grazing_within_clearance": boxes.crosses_box(Vector3(80.0, 0.0, 104.3), Vector3(120.0, 0.0, 104.3)),
		"clear_line_passes": not boxes.crosses_box(Vector3(80.0, 0.0, 105.0), Vector3(120.0, 0.0, 105.0)),
		"short_of_box": not boxes.crosses_box(Vector3(80.0, 0.0, 100.0), Vector3(90.0, 0.0, 100.0)),
	}
	boxes.reset(0.5)
	checks["reset_forgets"] = boxes.is_empty() and not boxes.crosses_box(Vector3(80.0, 0.0, 100.0), Vector3(120.0, 0.0, 100.0))
	return _verdict(checks, {})


## 024e: the three difficulties (RFC-024 §6 024e). Normal = the original (periods 12/60/6/6/60/12, aggression 1, no delay); Easy x2,
## 0.6, 0.5 s; Hard x0.75 (rounded down), 1.0, perfect information. No difficulty has a bonus: resource_bonus is locked at 0 (setting
## another value leaves 0). Normal applied to the original profile gives that same profile (nothing is copied).
func _difficulties() -> Dictionary:
	var original: AiProfile = load("res://data/ai/profile_original.tres")
	var easy: AiDifficulty = load("res://data/ai/difficulty_easy.tres")
	var normal: AiDifficulty = load("res://data/ai/difficulty_normal.tres")
	var hard: AiDifficulty = load("res://data/ai/difficulty_hard.tres")
	var checks := {"loaded": original != null and easy != null and normal != null and hard != null}
	if not checks["loaded"]:
		return _verdict(checks)
	var easy_profile := easy.apply_to(original)
	var hard_profile := hard.apply_to(original)
	checks["normal_is_original"] = normal.apply_to(original) == original and not normal.perfect_information and normal.delay_ticks(60) == 0
	checks["easy_periods"] = easy_profile.slot_periods == PackedInt32Array([24, 120, 12, 12, 120, 24])
	checks["easy_aggression"] = easy_profile.aggression == 0.6 and easy.delay_ticks(60) == 30 and not easy.perfect_information
	checks["hard_periods"] = hard_profile.slot_periods == PackedInt32Array([9, 45, 4, 4, 45, 9])
	checks["hard_aggression"] = hard_profile.aggression == 1.0 and hard.delay_ticks(60) == 0 and hard.perfect_information
	checks["original_untouched"] = original.slot_periods == PackedInt32Array([12, 60, 6, 6, 60, 12]) and original.aggression == 1.0
	## Adenda 1.3: only Easy paces its summons and keeps a reserve; Normal and Hard are the original (0 and 0).
	checks["summon_pace"] = easy.summon_interval_s > 0.0 and easy.mana_reserve > 0.0 and normal.summon_interval_s == 0.0 \
			and normal.mana_reserve == 0.0 and hard.summon_interval_s == 0.0 and hard.mana_reserve == 0.0 and normal.summon_interval_ticks(60) == 0
	checks["no_bonus"] = easy.resource_bonus == 0.0 and normal.resource_bonus == 0.0 and hard.resource_bonus == 0.0
	var probe := AiDifficulty.new()
	probe.resource_bonus = 0.5
	checks["bonus_locked"] = probe.resource_bonus == 0.0
	return _verdict(checks, {"easy": easy_profile.slot_periods, "hard": hard_profile.slot_periods})


## 024e: one profile per god with the numbers of the original (the original has no personality; the god changes only the book).
func _profiles_by_god() -> Dictionary:
	var original: AiProfile = load("res://data/ai/profile_original.tres")
	var checks := {}
	var differ := {}
	for god in GameData.gods():
		var profile := AiProfile.for_type(GameData.god(god))
		checks[god] = profile != null and profile != original and profile.god == StringName(god)
		if profile == null:
			continue
		for prop in profile.get_property_list():
			if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) or str(prop["name"]) == "god":
				continue
			if profile.get(prop["name"]) != original.get(prop["name"]):
				differ["%s.%s" % [god, prop["name"]]] = [profile.get(prop["name"]), original.get(prop["name"])]
	checks["same_numbers"] = differ.is_empty()
	checks["five_gods"] = GameData.gods().size() == 5
	return _verdict(checks, {"differ": differ})


## 024e (N1/N2 of REVIEW-RFC-024c): without perfect information the AI keeps, of an enemy body its side does not see, the position,
## health and mana it saw last, and cannot aim a cast at it; once the side sees it, the real ones. With perfect information it reads the
## real state, and each such read of an unseen body is counted.
func _limited_information(host: Node3D) -> Dictionary:
	var perception := AiPerception.new()
	perception.name = "AiCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 2
	host.add_child(perception)
	var port := AiCommandPort.new()
	port.perception = perception
	host.add_child(port)
	var foe := _unit(host, 1, Vector3(700.0, 0.0, 700.0))
	await host.get_tree().process_frame
	var checks := {}
	var t := perception.add_node(foe, &"scan")
	checks["tracked"] = t != null
	if t == null:
		for node: Node in [perception, port, foe]:
			node.queue_free()
		return _verdict(checks)
	var seen_at := t.cur_pos
	var hp_seen := perception.health_of(t)
	foe.global_position = Vector3(760.0, 0.0, 700.0)
	foe.get_node("Health").set("current", hp_seen.x * 0.5)
	checks["unseen_keeps_position"] = perception.pos_of(t) == seen_at
	checks["unseen_keeps_health"] = perception.health_of(t) == hp_seen
	checks["unseen_cannot_aim"] = not port.can_aim(t)
	checks["no_reads"] = perception.unseen_reads == 0
	t.seen = true
	perception._update_node(t, 1)
	checks["frozen_track"] = t.frozen and t.cur_pos == seen_at
	## A body of its side stands next to the foe and looks: the side sees it now.
	var watcher := _unit(host, 2, Vector3(740.0, 0.0, 700.0))
	var eyes := watcher.get("vision") as Vision
	eyes.watching = false
	eyes.refresh()
	checks["seen_real_position"] = perception.pos_of(t).distance_to(Vector3(760.0, 0.0, 700.0)) < 0.01
	checks["seen_real_health"] = perception.health_of(t).x == AiRater.ftol(hp_seen.x * 0.5)
	checks["seen_can_aim"] = port.can_aim(t)
	perception._update_node(t, 1)
	checks["followed_again"] = not t.frozen and t.cur_pos.distance_to(Vector3(760.0, 0.0, 700.0)) < 0.01
	var other := _unit(host, 1, Vector3(720.0, 0.0, 720.0))
	var u := perception.add_node(other, &"scan")
	perception.perfect_information = true
	other.global_position = Vector3(730.0, 0.0, 720.0)
	checks["perfect_reads_real"] = u != null and perception.pos_of(u).distance_to(Vector3(730.0, 0.0, 720.0)) < 0.01
	checks["perfect_read_counted"] = perception.unseen_reads == 1
	checks["perfect_can_aim"] = u != null and port.can_aim(u)
	for node: Node in [watcher, perception, port, foe, other]:
		node.queue_free()
	return _verdict(checks, {"seen_at": seen_at, "reads": perception.unseen_reads})


## F75 debt: the AI does not ask Convert again on a soul whose Convert is under way. The game reserves the soul for the caster's side
## while its cast and doctor run (Soul.reserve_for, sacengine convertSideMask) and the AI's search filters with the same rule
## (AiPerception.find_best_near -> SacrificeSystem.convert_status -> Soul.can_convert_by). Measured in 024e: every Convert of the AI
## in ai_vs_trivial seed 1 (13 in 6 min) took a different soul; the casts seen in the playtest were parallel errands, not repeats.
func _reserved_soul() -> Dictionary:
	var soul := Soul.new()
	soul.owner_slot = 3
	soul.attached = true
	var checks := {"red_free": soul.can_convert_by(2)}
	soul.reserve_for(2)
	checks["reserved_not_again"] = not soul.can_convert_by(2)
	checks["other_side_still"] = soul.can_convert_by(1)
	soul.release_for(2)
	checks["released_free"] = soul.can_convert_by(2)
	soul.free()
	return _verdict(checks)


## 024e, without perfect information: the side looks where it last knew a foe (an own body has the place in its sight) and the foe is
## not seen: the AI forgets it; once its side sees it again it knows it again. With perfect information nothing is forgotten.
func _forget_checked(host: Node3D) -> Dictionary:
	var perception := AiPerception.new()
	perception.name = "AiCasesPerception2"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 2
	host.add_child(perception)
	var foe := _unit(host, 1, Vector3(900.0, 0.0, 900.0))
	var mine := _unit(host, 2, Vector3(960.0, 0.0, 900.0))
	var eyes := mine.get("vision") as Vision
	eyes.watching = false
	await host.get_tree().process_frame
	var checks := {}
	var t := perception.add_node(foe, &"scan")
	perception.add_node(mine, &"event")
	foe.global_position = Vector3(1300.0, 0.0, 900.0)
	var sight := eyes.range_m()
	checks["sight_covers"] = sight >= 60.0
	perception.perfect_information = true
	perception.update_nodes(1)
	checks["perfect_keeps"] = perception.find(foe) != null and perception.forgotten == 0
	perception.perfect_information = false
	perception.update_nodes(1)
	checks["forgotten"] = perception.find(foe) == null and perception.forgotten == 1
	foe.global_position = Vector3(1000.0, 0.0, 900.0)
	eyes.refresh()
	perception.update_nodes(1)
	var again := perception.find(foe)
	checks["known_again"] = again != null and again.seen
	for node: Node in [perception, foe, mine]:
		node.queue_free()
	return _verdict(checks, {"sight": sight, "tracked": t != null})


## RFC-053 053b (F371): what a Wrath (oalf: 550, damage_range 5 m) bursting at a point would take from an own body, by
## SplashDamage's formula and the side factor (friendly fire on, ×0.5). By hand for a Ranger (amuh, 800 health, capsule radius r):
## at 1 m from its feet, box distance 1 - r, so 550·(1 - (1 - r)/5)·0.5/800 > 0.27 > own_splash_max_ratio 0.1 (veto); at 15 m it
## is past the 5 m: 0. With friendly fire off the own body takes 0 (Health._side_factor).
func _own_splash(host: Node3D) -> Dictionary:
	var state := MatchState.new()
	state.name = "AiCasesMatchState"
	host.add_child(state)
	state.friendly_fire = true
	state.ally_damage_factor = 0.5
	var perception := AiPerception.new()
	perception.name = "AiCasesPerception3"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 2
	host.add_child(perception)
	var type := GameData.creature("amuh")
	var ranger: Node3D = UNIT_SCENE.instantiate()
	ranger.name = "AiCasesRanger"
	ranger.position = Vector3(1100.0, 0.0, 1100.0)
	ranger.set("owner_slot", 2)
	ranger.set("type", GameData.creature("amuh"))
	ranger.set("model", type.model_id())
	ranger.set("rules", RULES)
	ranger.set("idle_aggro", false)
	host.add_child(ranger)
	await host.get_tree().process_frame
	var eval := AiSpellEval.new(perception, null, null, perception.profile)
	var wrath := GameData.spell("oalf")
	var checks := {"tracked": perception.add_node(ranger, &"event") != null}
	var at := ranger.global_position
	var near := AiAreaRating.own_splash(at + Vector3(1.0, 0.0, 0.0), wrath, null, perception, eval.tactics)
	var far := AiAreaRating.own_splash(at + Vector3(15.0, 0.0, 0.0), wrath, null, perception, eval.tactics)
	checks["one_state"] = host.get_tree().get_nodes_in_group(&"match_state").size() == 1
	checks["near_over_threshold"] = near > eval.tactics.own_splash_max_ratio and near > 0.27
	checks["far_zero"] = far == 0.0
	checks["direct_whole"] = _near(AiAreaRating.splash_loss(ranger, at + Vector3(15.0, 0.0, 0.0), wrath, 2, true), 550.0 * 0.5 / 800.0)
	state.friendly_fire = false
	var off := AiAreaRating.own_splash(at + Vector3(1.0, 0.0, 0.0), wrath, null, perception, eval.tactics)
	checks["friendly_fire_off_zero"] = off == 0.0
	for node: Node in [state, perception, ranger]:
		node.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks, {"near": near, "far": far, "off": off})


## RFC-053 §7, §9: one AiTactics per difficulty, wired into its AiDifficulty; a difficulty with none plays Normal's.
func _tactics() -> Dictionary:
	var checks := {}
	var expected := {
		"easy": {"heal_below_ratio": 0.45, "healer_weight": 1.0, "commit_hold_s": 3.0, "focus_max_members": 3},
		"normal": {"heal_below_ratio": 0.6, "healer_weight": 2.0, "commit_hold_s": 6.0, "focus_max_members": 6},
		"hard": {"heal_below_ratio": 0.7, "healer_weight": 3.0, "commit_hold_s": 8.0, "focus_max_members": 8},
	}
	var seen := {}
	for tag: String in expected:
		var difficulty: AiDifficulty = load("res://data/ai/difficulty_%s.tres" % tag)
		var tactics := difficulty.tactics_or_normal() if difficulty != null else null
		var ok := tactics != null and tactics.resource_path == "res://data/ai/tactics_%s.tres" % tag
		if ok:
			for key: String in expected[tag]:
				ok = ok and _near(float(tactics.get(key)), float(expected[tag][key]))
			ok = ok and tactics.los_check and _near(tactics.los_retry_factor, 0.5) and _near(tactics.own_splash_max_ratio, 0.1) \
				and tactics.own_splash_counts_wizard and tactics.npc_passive_weight == 0.0 and tactics.heal_min_missing == 100.0 \
				and _near(tactics.commit_weight, 1.5) and tactics.focus_kill_window_s == 20.0 and _near(tactics.focus_power_ratio, 1.2) \
				and tactics.focus_radius_m == 60.0
			seen[tag] = {"heal": tactics.heal_below_ratio, "healer": tactics.healer_weight, "hold": tactics.commit_hold_s, "members": tactics.focus_max_members}
		checks[tag] = ok
	checks["null_is_normal"] = AiDifficulty.new().tactics_or_normal().resource_path == AiTactics.NORMAL
	return _verdict(checks, seen)


## RFC-053 053c (F372): Heal rates 0 on a body at or over heal_below_ratio (Normal 0.6) of its health, on one that misses less than
## heal_min_missing (100), on one being summoned and on one with a heal running; a Trogg (960) at 30 % rates over 0.
func _heal_threshold(host: Node3D) -> Dictionary:
	var perception := AiPerception.new()
	perception.name = "AiCasesPerception4"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 2
	host.add_child(perception)
	var trogg: UnitBody = UNIT_SCENE.instantiate()
	trogg.name = "AiCasesHealTrogg"
	trogg.position = Vector3(1100.0, 0.0, 1100.0)
	trogg.owner_slot = 2
	trogg.type = GameData.creature("ycro")
	trogg.rules = RULES
	trogg.idle_aggro = false
	host.add_child(trogg)
	await host.get_tree().process_frame
	var eval := AiSpellEval.new(perception, null, null, perception.profile)
	var heal := GameData.spell("laeh") as SpellType
	var track := perception.add_node(trogg, &"event")
	var checks := {"tracked": track != null}
	var scores := {}
	if track != null:
		track.cached_rate = 1.0
		var health := trogg.get_node("Health") as Health
		for fraction: float in [0.3, 0.55, 0.6, 0.95, 1.0]:
			health.current = health.maximum * fraction
			scores[str(fraction)] = AiHealRating.heal(heal, track, perception, eval.tactics)
		checks["low_heals"] = float(scores["0.3"]) > 0.0 and float(scores["0.55"]) > 0.0
		checks["at_threshold_zero"] = float(scores["0.6"]) == 0.0
		checks["above_threshold_zero"] = float(scores["0.95"]) == 0.0 and float(scores["1.0"]) == 0.0
		checks["still_worth_follows"] = not eval.still_worth(heal, track) and eval.still_worth(GameData.spell("kcor"), track)
		var loose := eval.tactics.duplicate() as AiTactics
		loose.heal_below_ratio = 1.0
		eval.tactics = loose
		health.current = health.maximum - 50.0
		scores["missing_50"] = AiHealRating.heal(heal, track, perception, eval.tactics)
		checks["min_missing_zero"] = float(scores["missing_50"]) == 0.0
		eval.tactics = AiTactics.or_normal(null)
		health.current = health.maximum * 0.3
		trogg.begin_summon()
		scores["summoning"] = AiHealRating.heal(heal, track, perception, eval.tactics)
		trogg.finish_summon()
		checks["summoning_zero"] = float(scores["summoning"]) == 0.0
		HealEffect.on(trogg)
		scores["healing"] = AiHealRating.heal(heal, track, perception, eval.tactics)
		checks["heal_running_zero"] = float(scores["healing"]) == 0.0
	for node: Node in [perception, trogg]:
		node.queue_free()
	await host.get_tree().process_frame
	return _verdict(checks, scores)


## RFC-053 053d (F373): AiKillEstimate, by hand from the catalog. Ranger (amuh, Fire bow wobf: 120, cooldown 1.5 s; first shoot clip HAsh
## 58 frames at 30, shot at frame 36): a shot every max(58/30, 36/30 + 1.5) = 2.7 s, 120 / 2.7 = 44.444 per second to a body of
## resistance 1. Scarab (cara, Healing web slba: cooldown 6 s; clip BGs2 44 frames, shot at 22): a web every max(44/30, 22/30 + 6) =
## 6.7333 s that heals the whole bar at 240/s: 1500 / 6.7333 = 222.77 per second to a 1500 wizard, 240 at most. seconds = health /
## (dps - healing), INF when the healing keeps up.
func _kill_estimate() -> Dictionary:
	var ranger := GameData.creature("amuh")
	var scarab := GameData.creature("cara")
	var checks := {}
	checks["seconds_net"] = _near(AiKillEstimate.seconds(1200.0, 300.0, 60.0), 5.0)
	checks["seconds_dead"] = AiKillEstimate.seconds(0.0, 0.0, 10.0) == 0.0
	checks["seconds_outhealed"] = is_inf(AiKillEstimate.seconds(600.0, 50.0, 60.0))
	checks["ranger_period"] = _near(AiKillEstimate.shot_period(ranger, GameData.ability("wobf")), 2.7)
	checks["ranger_dps"] = _near(AiKillEstimate.dps_of(ranger, scarab), 44.4444)
	checks["ranger_not_healer"] = not AiKillEstimate.is_healer(ranger) and AiKillEstimate.heal_rate_of(ranger, 1500.0) == 0.0
	checks["scarab_healer"] = AiKillEstimate.is_healer(scarab) and AiKillEstimate.shot_heals("slba")
	checks["scarab_heal_wizard"] = _near(AiKillEstimate.heal_rate_of(scarab, 1500.0), 222.772)
	checks["scarab_heal_capped"] = _near(AiKillEstimate.heal_rate_of(scarab, 3000.0), 240.0)
	## four Rangers against a 1500 wizard healed by a Scarab: 177.78 < 222.77, they never kill him
	checks["four_rangers_outhealed"] = is_inf(AiKillEstimate.seconds(1500.0, 4.0 * AiKillEstimate.dps_of(ranger, null), AiKillEstimate.heal_rate_of(scarab, 1500.0)))
	return _verdict(checks, {"ranger_dps": AiKillEstimate.dps_of(ranger, scarab), "heal": AiKillEstimate.heal_rate_of(scarab, 1500.0),
		"period": AiKillEstimate.shot_period(ranger, GameData.ability("wobf"))})
