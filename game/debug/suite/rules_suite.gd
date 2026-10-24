extends Node3D

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const STRUCTURE_SCENE := preload("res://scenes/structures/structure.tscn")
const RULES := preload("res://data/match_rules.tres")
const DOCTOR_CASES := preload("res://debug/suite/doctor_cases.gd")  # 020b
const MATCH_CASES := preload("res://debug/suite/match_cases.gd")  # 020a
const ACTION_CASES := preload("res://debug/suite/action_cases.gd")  # 021a
const SACRIFICE_CASES := preload("res://debug/suite/sacrifice_cases.gd")  # 020c
const RITUAL_CASES := preload("res://debug/suite/ritual_cases.gd")  # 020d
const CONVERT_CASES := preload("res://debug/suite/convert_cases.gd")  # 020e
const GUARDIAN_CASES := preload("res://debug/suite/guardian_cases.gd")  # 021b
const TELEPORT_CASES := preload("res://debug/suite/teleport_cases.gd")  # 021c
const TARGET_CASES := preload("res://debug/suite/target_cases.gd")  # 024b
const NAV_CASES := preload("res://debug/suite/nav_cases.gd")  # 024b
const VILLAGE_CASES := preload("res://debug/suite/village_cases.gd")  # 024b2
const AI_CASES := preload("res://debug/suite/ai_cases.gd")  # 024c
const CROWD_CASES := preload("res://debug/suite/crowd_cases.gd")  # 027d
const DETERMINISM_CASES := preload("res://debug/suite/determinism_cases.gd")  # 032b
const FORMATION_CASES := preload("res://debug/suite/formation_cases.gd")  # 038a, 038b
const RADIAL_CASES := preload("res://debug/suite/radial_cases.gd")  # 038c
const HOVER_FRAME_CASES := preload("res://debug/suite/hover_frame_cases.gd")
const DEATH_CASES := preload("res://debug/suite/death_cases.gd")  # 055a
const BIOME_CASES := preload("res://debug/suite/biome_cases.gd")
const TEAM_CASES := preload("res://debug/match/team_cases.gd")  # 049b, 049c

@export var auto_run := true
@export var max_spawned_units := 12
@export var max_spawned_structures := 4

## F139: the world of the «fuego amigo» case. MatchState reads its rules (world.rules), never its own.
var rules: MatchRules

var _results: Dictionary = {}


func _ready() -> void:
	if auto_run:
		call_deferred("_run_suite")


func _run_suite() -> void:
	_results = {
		"unit_interactions": _test_unit_interactions(),
		"battles": _test_battles(),
		"unit_death": _test_unit_death(),
		"buildings": _test_buildings(),
		"destruction": _test_desctruction(),
	}
	_results.merge(await DOCTOR_CASES.new().run(self))  # 020b
	_results.merge(MATCH_CASES.new().run(self))  # 020a
	_results.merge(ACTION_CASES.new().run(self))  # 021a
	_results.merge(await SACRIFICE_CASES.new().run(self))  # 020c
	_results.merge(await RITUAL_CASES.new().run(self))  # 020d
	_results.merge(await CONVERT_CASES.new().run(self))  # 020e
	_results.merge(await GUARDIAN_CASES.new().run(self))  # 021b
	_results.merge(await TELEPORT_CASES.new().run(self))  # 021c
	_results.merge(await TARGET_CASES.new().run(self))  # 024b
	_results.merge(await NAV_CASES.new().run(self))  # 024b
	_results.merge(VILLAGE_CASES.new().run(self))  # 024b2
	_results.merge(await AI_CASES.new().run(self))  # 024c
	_results.merge(await CROWD_CASES.new().run(self))  # 027d
	_results["friendly_fire"] = await _test_friendly_fire()  # 031a
	_results.merge(await DETERMINISM_CASES.new().run(self))  # 032b
	_results.merge(await FORMATION_CASES.new().run(self))  # 038a, 038b
	_results.merge(RADIAL_CASES.new().run(self))  # 038c
	_results.merge(await HOVER_FRAME_CASES.new().run(self))
	_results.merge(await DEATH_CASES.new().run(self))  # 055a
	_results.merge(await TEAM_CASES.new().run(self))  # 049b, 049c
	_results.merge(BIOME_CASES.new().run(self))
	_print_suite()


func _test_unit_interactions() -> Dictionary:
	var roster := _all_unit_tags()
	if roster.is_empty():
		return {"ok": false, "reason": "roster vacio", "count": 0}
	var limit := mini(roster.size(), max_spawned_units)
	for index in range(limit):
		var tag := roster[index]
		var type := GameData.creature(tag)
		if type == null:
			return {"ok": false, "reason": "creature missing: %s" % tag, "count": index}
		var unit := _spawn_unit(tag, 1, Vector3(index * 2.0, 0.0, 0.0))
		if unit == null:
			return {"ok": false, "reason": "unit null: %s" % tag, "count": index}
		var health: Node = unit.get_node("Health")
		if not health.has_method("damage_typed"):
			return {"ok": false, "reason": "Health sin damage_typed: %s" % tag, "count": index}
		if unit.get("owner_slot") != 1:
			return {"ok": false, "reason": "owner_slot mismatch: %s" % tag, "count": index}
		if unit.get("creature_tag") != tag:
			return {"ok": false, "reason": "creature_tag mismatch: %s" % tag, "count": index}
		if str(unit.display_name()) != str(type.display_name):
			return {"ok": false, "reason": "display_name mismatch: %s" % tag, "count": index}
		if unit.has_method("begin_walk"):
			unit.call("begin_walk", Vector3(20.0, 0.0, 0.0))
		if unit.has_method("engage"):
			unit.call("engage", unit)
		unit.queue_free()
	return {"ok": true, "count": limit, "roster": roster.slice(0, limit)}


func _test_battles() -> Dictionary:
	var roster := _all_unit_tags()
	if roster.size() < 2:
		return {"ok": false, "reason": "roster too small"}
	var attacker_tag := roster[0]
	var defender_tag := roster[1]
	if GameData.creature(attacker_tag) == null or GameData.creature(defender_tag) == null:
		return {"ok": false, "reason": "tags missing"}
	var attacker := _spawn_unit(attacker_tag, 1, Vector3.ZERO)
	var defender := _spawn_unit(defender_tag, 2, Vector3(5.0, 0.0, 0.0))
	if attacker == null or defender == null:
		return {"ok": false, "reason": "battle units null"}
	attacker.call("engage", defender)
	var health: Node = defender.get_node("Health")
	health.call("setup", 120.0)
	var before := float(health.get("current"))
	var taken := float(health.call("damage_typed", 45.0, &"melee", 1))
	var after := float(health.get("current"))
	var ok := taken > 0.0 and before > after and attacker.get("mode") != null
	attacker.queue_free()
	defender.queue_free()
	return {"ok": ok, "before": before, "after": after, "taken": taken}


## A unit that takes its whole health is dead; the one next to it is not.
func _test_unit_death() -> Dictionary:
	var roster := _all_unit_tags()
	if roster.size() < 2:
		return {"ok": false, "reason": "roster too small"}
	var survivor := _spawn_unit(roster[0], 1, Vector3.ZERO)
	var victim := _spawn_unit(roster[1], 2, Vector3(2.0, 0.0, 0.0))
	if survivor == null or victim == null:
		return {"ok": false, "reason": "survivor/victim null"}
	var survivor_health := survivor.get_node("Health")
	var victim_health := victim.get_node("Health")
	survivor_health.call("setup", 20.0)
	victim_health.call("setup", 20.0)
	victim_health.call("damage", 20.0, 1)
	var survivor_ok: bool = !bool(survivor.call("is_dead"))
	var victim_ok: bool = bool(victim.call("is_dead"))
	survivor.queue_free()
	victim.queue_free()
	return {"ok": survivor_ok and victim_ok, "survivor_alive": survivor_ok, "victim_dead": victim_ok}


func _test_buildings() -> Dictionary:
	var count := 0
	for index in range(max_spawned_structures):
		var structure := _spawn_structure("htlm", 1, Vector3(index * 10.0, 0.0, 0.0))
		if structure == null:
			return {"ok": false, "reason": "structure null", "count": index}
		var health: Node = structure.get_node("Health")
		if not health or not health.has_method("setup"):
			return {"ok": false, "reason": "structure health missing", "count": index}
		if str(structure.get("spell_tag")) != "htlm":
			return {"ok": false, "reason": "spell_tag mismatch", "count": index}
		if str(structure.get("model")) != "mana":
			return {"ok": false, "reason": "model mismatch", "count": index}
		count += 1
		structure.queue_free()
	return {"ok": true, "count": count}


func _test_desctruction() -> Dictionary:
	var structure := _spawn_structure("htlm", 1, Vector3.ZERO)
	if structure == null:
		return {"ok": false, "reason": "structure null"}
	var health: Node = structure.get_node("Health")
	health.call("setup", 300.0)
	health.call("damage", 300.0, 2)
	var ok := bool(structure.call("is_dead"))
	structure.queue_free()
	return {"ok": ok, "destroyed": ok}


## F139 (RFC-031 031a): Health._side_factor with the rule MatchState takes from the world's rules. Two Druids of slot 1 and
## one of slot 2, hit by slot 1. On: splash and melee ×ally_damage_factor (0.5), poison ×1 (ignoreFriendly). Off: 0 on
## every path. The MatchState's own `rules` is the product's (on); with the world's off the own side still takes 0.
func _test_friendly_fire() -> Dictionary:
	var world_rules := RULES.duplicate() as MatchRules
	world_rules.friendly_fire = true
	rules = world_rules
	var state := MatchState.new()
	state.rules = RULES
	state.world = self
	add_child(state)
	var own := _spawn_unit("nmuh", 1, Vector3(0.0, 0.0, 60.0))
	var foe := _spawn_unit("nmuh", 2, Vector3(6.0, 0.0, 60.0))
	var own_health := own.get_node("Health") as Health
	var foe_health := foe.get_node("Health") as Health
	own_health.setup(5000.0)
	foe_health.setup(5000.0)
	var out := {}
	out["on_rule"] = state.friendly_fire and is_equal_approx(state.ally_damage_factor, 0.5)
	var own_splash := own_health.damage_typed(100.0, Health.SPLASH_SPELL, 1)
	var foe_splash := foe_health.damage_typed(100.0, Health.SPLASH_SPELL, 1)
	out["on_splash_ratio"] = own_splash / foe_splash if foe_splash > 0.0 else -1.0
	var before := own_health.current
	own_health.damage(100.0, 1)
	out["on_melee_taken"] = before - own_health.current
	out["on_poison_ratio"] = await _poison_ratio(own_health, foe_health)
	var trap := RULES.friendly_fire
	world_rules.friendly_fire = false
	state.take_rules()
	out["off_rule"] = not state.friendly_fire
	out["off_splash"] = own_health.damage_typed(100.0, Health.SPLASH_SPELL, 1)
	before = own_health.current
	own_health.damage(100.0, 1)
	out["off_melee_taken"] = before - own_health.current
	var poison := await _poison_taken(own, foe)
	out["off_poison_own"] = poison[0]
	out["off_poison_foe"] = poison[1]
	var ok: bool = bool(out["on_rule"]) and absf(float(out["on_splash_ratio"]) - 0.5) <= 0.005 \
		and absf(float(out["on_melee_taken"]) - 50.0) <= 0.01 and absf(float(out["on_poison_ratio"]) - 1.0) <= 0.01 \
		and trap and bool(out["off_rule"]) and float(out["off_splash"]) == 0.0 and float(out["off_melee_taken"]) == 0.0 \
		and float(out["off_poison_own"]) == 0.0 and float(out["off_poison_foe"]) > 0.0
	out["ok"] = ok
	print("fuego amigo caso %s" % out)
	own.queue_free()
	foe.queue_free()
	state.queue_free()
	rules = null
	return out


## The same dose of poison from slot 1 on both bodies: taken by `own` / taken by `foe`.
func _poison_ratio(own_health: Health, foe_health: Health) -> float:
	var taken := await _poison_taken(own_health.get_parent(), foe_health.get_parent())
	return taken[0] / taken[1] if taken[1] > 0.0 else -1.0


func _poison_taken(own: Node, foe: Node) -> Array[float]:
	var own_dose := Poisoning.dose_body(own, 60.0, 30, Health.SPLASH_SPELL, 1)
	var foe_dose := Poisoning.dose_body(foe, 60.0, 30, Health.SPLASH_SPELL, 1)
	var taken: Array[float] = [0.0, 0.0]
	for _frame in 40:
		if is_instance_valid(own_dose):
			taken[0] = float(own_dose.get("taken"))
		if is_instance_valid(foe_dose):
			taken[1] = float(foe_dose.get("taken"))
		await get_tree().physics_frame
	return taken


func _all_unit_tags() -> PackedStringArray:
	var seen: Dictionary = {}
	var result := PackedStringArray()
	for god in GameData.gods():
		var entry: Dictionary = GameData.book(god)
		for creature: Variant in entry.get("creatures", []):
			if creature == null:
				continue
			var tag := str(creature.tag)
			if tag.is_empty() or seen.has(tag):
				continue
			seen[tag] = true
			result.append(tag)
	result.sort()
	return result


func _spawn_unit(tag: String, owner_slot: int, position: Vector3) -> Node3D:
	var type := GameData.creature(tag)
	if type == null:
		return null
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = "TestUnit_%s" % tag
	unit.position = position
	unit.set("owner_slot", owner_slot)
	unit.set("creature_tag", tag)
	unit.set("model", str(type.model))
	unit.set("rules", RULES)
	unit.set("mode", 0)
	add_child(unit)
	return unit


func _spawn_structure(tag: String, owner_slot: int, position: Vector3) -> Node3D:
	var structure: Node3D = STRUCTURE_SCENE.instantiate()
	structure.name = "TestStructure_%s" % tag
	structure.position = position
	structure.set("owner_slot", owner_slot)
	structure.set("spell_tag", tag)
	structure.set("model", "mana")
	structure.set("rules", RULES)
	add_child(structure)
	return structure


func _print_suite() -> void:
	var failures := 0
	print("== Rules suite ==")
	for name in _results.keys():
		var item: Dictionary = _results[name]
		var ok := bool(item.get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % item)
	if failures == 0:
		print("RULES SUITE PASS")
	else:
		print("RULES SUITE FAIL (%d)" % failures)
	## Headless (CI and the bench commands) ends by itself; with a window it stays on screen.
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures == 0 else 1)
