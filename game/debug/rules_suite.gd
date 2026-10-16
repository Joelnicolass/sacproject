extends Node3D

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const STRUCTURE_SCENE := preload("res://scenes/world/structures/structure.tscn")
const RULES := preload("res://data/match_rules.tres")
const DOCTOR_CASES := preload("res://debug/doctor_cases.gd")  # 020b
const MATCH_CASES := preload("res://debug/match_cases.gd")  # 020a
const ACTION_CASES := preload("res://debug/action_cases.gd")  # 021a
const SACRIFICE_CASES := preload("res://debug/sacrifice_cases.gd")  # 020c
const RITUAL_CASES := preload("res://debug/ritual_cases.gd")  # 020d
const CONVERT_CASES := preload("res://debug/convert_cases.gd")  # 020e
const GUARDIAN_CASES := preload("res://debug/guardian_cases.gd")  # 021b
const TELEPORT_CASES := preload("res://debug/teleport_cases.gd")  # 021c
const TARGET_CASES := preload("res://debug/target_cases.gd")  # 024b
const NAV_CASES := preload("res://debug/nav_cases.gd")  # 024b
const VILLAGE_CASES := preload("res://debug/village_cases.gd")  # 024b2
const AI_CASES := preload("res://debug/ai_cases.gd")  # 024c
const CROWD_CASES := preload("res://debug/crowd_cases.gd")  # 027d

@export var auto_run := true
@export var max_spawned_units := 12
@export var max_spawned_structures := 4

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
	_results.merge(NAV_CASES.new().run(self))  # 024b
	_results.merge(VILLAGE_CASES.new().run(self))  # 024b2
	_results.merge(await AI_CASES.new().run(self))  # 024c
	_results.merge(await CROWD_CASES.new().run(self))  # 027d
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
