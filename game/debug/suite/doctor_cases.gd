extends RefCounted

## RFC-020b cases of rules_suite: the Sac Doctor measured in simulated physics frames, not computed.
## `run(host)` adds its own floor and bodies under `host` and removes them when it ends.

const DOCTOR_SCENE := preload("res://scenes/sacrifice/doctor.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")
## Direct spells of Caster (kcor Rock, oalf Wrath, brif Fireball, ntil Lightning, mrws Swarm).
const DIRECT_SPELLS: Array[String] = ["kcor", "oalf", "brif", "ntil", "mrws"]
const ATTACKERS: Array[String] = ["nmuh", "ycro"]
const LAYOUTS: Array[String] = ["frente", "anillo"]
const MELEE_CAP_S := 20.0

var _host: Node3D
var _floor: StaticBody3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	_floor.add_child(shape)
	_host.add_child(_floor)
	await _frames(2)
	var out := {}
	out["doctor_stats"] = await _stats()
	out["doctor_regen"] = await _regen()
	out["doctor_one_shot"] = await _one_shot()
	out["doctor_melee"] = await _melee()
	_floor.queue_free()
	return out


func _stats() -> Dictionary:
	var type := GameData.creature("dcas")
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	await _frames(3)
	var health: Health = doctor.health
	var ok := type != null
	ok = ok and is_equal_approx(health.maximum, 400.0) and is_equal_approx(health.current, 400.0)
	ok = ok and is_equal_approx(doctor.pace(), 10.0)
	ok = ok and is_equal_approx(type.regeneration_per_s, 83.3333)
	ok = ok and doctor.is_in_group("doctor") and not doctor.is_in_group("unit")
	ok = ok and Attackable.is_body(doctor) and _attackable_matches_old_groups()
	ok = ok and not doctor.has_node("Orders") and not doctor.has_node("MeleeAttack")
	var result := {"ok": ok, "health": health.maximum, "speed": doctor.pace(), "regen": type.regeneration_per_s if type else 0.0}
	doctor.queue_free()
	return result


## Attackable keeps the old «wizard, unit or structure, and not a corpse» and adds «doctor».
func _attackable_matches_old_groups() -> bool:
	var ok := true
	for group in ["wizard", "unit", "structure", "doctor"]:
		var node := Node.new()
		node.add_to_group(group)
		_host.add_child(node)
		ok = ok and Attackable.is_body(node)
		node.add_to_group("corpse")
		ok = ok and not Attackable.is_body(node)
		node.queue_free()
	var other := Node.new()
	other.add_to_group("altar")
	_host.add_child(other)
	ok = ok and not Attackable.is_body(other)
	other.queue_free()
	return ok


func _regen() -> Dictionary:
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	await _frames(3)
	var health: Health = doctor.health
	health.damage_typed(100.0, Health.DIRECT_SPELL, 1)
	var hit := health.current
	var frames := 0
	var half_s := 0.0
	while health.current < health.maximum and frames < 180:
		await _frames(1)
		frames += 1
		if frames == 30:
			half_s = health.current
	var seconds := float(frames) / _fps()
	var result := {"ok": hit == 300.0 and seconds < 1.5 and half_s > 300.0 + 83.33 * 0.5 * 0.9, "after_hit": hit, "half_s": half_s, "full_s": seconds}
	doctor.queue_free()
	return result


func _one_shot() -> Dictionary:
	var kills := {}
	for tag in DIRECT_SPELLS:
		var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
		await _frames(2)
		var spell := GameData.spell(tag)
		var damage := float(spell.damage) if spell else 0.0
		doctor.health.damage_typed(damage, Health.DIRECT_SPELL, 1)
		kills[tag] = {"damage": damage, "dead": doctor.is_dead()}
		print("doctor_one_shot %s: %d de dano directo contra %d de vida -> %s" % [tag, roundi(damage), roundi(doctor.health.maximum), "muere de un golpe" if doctor.is_dead() else "sobrevive con %d" % roundi(doctor.health.current)])
		doctor.queue_free()
		await _frames(2)
	var rock: Dictionary = kills["kcor"]
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	await _frames(2)
	doctor.health.damage_typed(float(rock["damage"]), Health.DIRECT_SPELL, 1)
	var dying := doctor.is_dead() and not doctor.is_in_group("doctor")
	await _frames(int(RULES.doctor_death_s * _fps()) + 10)
	var gone := not is_instance_valid(doctor)
	var leftovers := _host.get_tree().get_nodes_in_group("corpse").size() + _host.get_tree().get_nodes_in_group("soul").size()
	return {"ok": bool(rock["dead"]) and dying and gone and leftovers == 0, "spells": kills, "freed": gone, "corpse_or_soul": leftovers}


## Sustained melee: 1 to 4 attackers of the roster against a standing doctor, two layouts around it.
func _melee() -> Dictionary:
	var rows: Array[Dictionary] = []
	for tag in ATTACKERS:
		for layout in LAYOUTS:
			for count in range(1, 5):
				var row := await _melee_run(tag, layout, count)
				rows.append(row)
				print("doctor_melee %s %s x%d: %s" % [tag, layout, count, "muere a los %.1f s (primer golpe %.1f s)" % [row["died_s"], row["first_hit_s"]] if row["dead"] else "no muere en %d s" % int(MELEE_CAP_S)])
	var ring_druids: Dictionary = {}
	for row in rows:
		if row["tag"] == "nmuh" and row["layout"] == "anillo" and row["count"] == 4:
			ring_druids = row
	return {"ok": bool(ring_druids.get("dead", false)), "rows": rows.size(), "druid_ring_4_s": ring_druids.get("died_s", -1.0)}


func _melee_run(tag: String, layout: String, count: int) -> Dictionary:
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	var attackers: Array[Node3D] = []
	for i in count:
		var angle := deg_to_rad(-30.0 + 20.0 * i) if layout == "frente" else deg_to_rad(45.0 + 90.0 * i)
		var unit: Node3D = UNIT_SCENE.instantiate()
		unit.set("type", GameData.creature(tag))
		unit.set("owner_slot", 1)
		unit.set("idle_aggro", false)
		unit.set("rng_seed", 100 + i)
		unit.set("rules", RULES)
		unit.position = Vector3(sin(angle), 0.0, cos(angle)) * 6.0 + Vector3(0.0, 0.1, 0.0)
		_host.add_child(unit)
		attackers.append(unit)
	await _frames(4)
	for unit in attackers:
		unit.call("engage", doctor)
	var first_hit := -1.0
	var frames := 0
	var limit := int(MELEE_CAP_S * _fps())
	var health: Health = doctor.health
	while not doctor.is_dead() and frames < limit:
		await _frames(1)
		frames += 1
		if first_hit < 0.0 and health.current < health.maximum:
			first_hit = float(frames) / _fps()
	var result := {"tag": tag, "layout": layout, "count": count, "dead": doctor.is_dead(), "died_s": float(frames) / _fps(), "first_hit_s": first_hit}
	for unit in attackers:
		unit.queue_free()
	doctor.queue_free()
	await _frames(2)
	return result


func _doctor(at: Vector3) -> DoctorBody:
	var doctor: DoctorBody = DOCTOR_SCENE.instantiate()
	doctor.owner_slot = 2
	doctor.rules = RULES
	doctor.position = at
	_host.add_child(doctor)
	return doctor


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _fps() -> float:
	return float(Engine.physics_ticks_per_second)
