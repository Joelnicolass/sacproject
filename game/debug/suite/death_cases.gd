extends RefCounted

## RFC-055 055a-1 cases of rules_suite: what a death does in the game. A creature on the ground dies and its soul appears
## once the body rests (the health bar already hidden); a flier dies in the air and ends on the floor with its soul at
## floor height; a doctor that dies carrying a creature drops it dead (soul where it lands) or alive, by the match rule.
## `run(host)` adds its own floor and bodies under `host` and removes them at the end. No network: everything runs as solo.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const DOCTOR_SCENE := preload("res://scenes/sacrifice/doctor.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const RULES := preload("res://data/match_rules.tres")
## Frames a scenario may take before it counts as stuck.
const GUARD_FRAMES := 1200

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "DeathCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_root.add_child(SOUL_SYSTEM_SCENE.instantiate())
	_host.add_child(_root)
	await _frames(2)
	var out := {}
	out["death_rules"] = _rules()
	out["death_ground"] = await _ground()
	out["death_flier"] = await _flier()
	out["death_look"] = await _look()
	out["death_carrier_rule_on"] = await _carrier(true)
	out["death_carrier_rule_off"] = await _carrier(false)
	_root.queue_free()
	return out


## The pure rules: souls, and what becomes of a creature that loses its carrier.
func _rules() -> Dictionary:
	var held := DeathRules.Carried.HELD
	var checks := {
		"soul_left": DeathRules.leaves_soul(1, false) and not DeathRules.leaves_soul(0, false) and not DeathRules.leaves_soul(1, true),
		"held_rule_on": DeathRules.on_carrier_lost(held, true, true) == DeathRules.Outcome.DROP_DEAD,
		"held_rule_off": DeathRules.on_carrier_lost(held, true, false) == DeathRules.Outcome.LAND_ALIVE,
		"reviving_always_dies": DeathRules.on_carrier_lost(DeathRules.Carried.REVIVING, true, false) == DeathRules.Outcome.DROP_DEAD,
		"dead_stays_dead": DeathRules.on_carrier_lost(held, false, false) == DeathRules.Outcome.DROP_DEAD,
	}
	return _verdict(checks)


## A creature on the ground dies: no soul while it falls, the soul where it rests, no bar over the corpse.
func _ground() -> Dictionary:
	var unit := _unit("nmuh", Vector3(0.0, 0.0, 10.0))
	await _frames(5)
	var bar := unit.get_node("HealthBar") as UnitHealthBar
	var corpse := unit.corpse()
	var checks := {"bar_shown_alive": bar.visible}
	(unit.get_node("Health") as Health).damage(99999.0, 1)
	await _frames(5)
	checks["dead"] = unit.is_dead() and unit.is_in_group("corpse")
	checks["not_settled_yet"] = not corpse.is_settled and _soul_of(unit) == null
	var took := await _until(func() -> bool: return corpse.is_settled, GUARD_FRAMES)
	await _frames(2)
	var soul := _soul_of(unit)
	checks["settled_after_fall_ticks"] = took >= 0 and took + 5 >= corpse.fall_ticks - 1
	checks["soul_at_corpse"] = soul != null and soul.attached and Vector2(soul.global_position.x - unit.global_position.x, soul.global_position.z - unit.global_position.z).length() < 1.0
	checks["bar_hidden"] = not bar.visible
	unit.free()
	return _verdict(checks)


## A flier dies at height: it falls, ends on the floor, and its soul is at floor height.
func _flier() -> Dictionary:
	var unit := _unit("sohe", Vector3(0.0, 0.0, 10.0))
	var checks := {}
	await _until(func() -> bool: return unit.global_position.y > 3.0, GUARD_FRAMES)
	checks["flying_high"] = unit.global_position.y > 3.0
	var corpse := unit.corpse()
	(unit.get_node("Health") as Health).damage(99999.0, 1)
	var took := await _until(func() -> bool: return corpse.is_settled, GUARD_FRAMES)
	await _frames(2)
	checks["settled"] = took >= 0
	checks["on_the_floor"] = unit.global_position.y < 0.5 and unit.is_on_floor()
	var soul := _soul_of(unit)
	checks["soul_at_floor_height"] = soul != null and soul.global_position.y < 2.5
	unit.free()
	return _verdict(checks)


## RFC-055 055a-2: the look of a death. A body with no clip tips over (the model, not the body), fades out when it
## dissolves, and its soul rises on screen without the soul moving.
func _look() -> Dictionary:
	var unit := _unit("nmuh", Vector3(0.0, 0.0, 10.0))
	await _frames(5)
	var mesh := unit.find_child("Mesh", true, false) as BodyVisual
	var look := unit.find_child("CorpseLook", false, false) as CorpseLook
	var checks := {"upright_alive": is_zero_approx(mesh.rotation.x)}
	var corpse := unit.corpse()
	(unit.find_child("Health", false, false) as Health).damage(99999.0, 1)
	await _until(func() -> bool: return corpse.is_settled, GUARD_FRAMES)
	await _until(func() -> bool: return mesh.rotation.x < -1.5, GUARD_FRAMES)
	checks["model_tipped"] = mesh.rotation.x < -1.5
	checks["body_not_rotated"] = is_zero_approx((mesh.get_parent() as Node3D).rotation.x) and is_zero_approx(unit.rotation.x)
	await _frames(2)
	var soul := _soul_of(unit)
	checks["soul_there"] = soul != null
	if soul != null:
		var before := soul.global_position
		var visual := soul.find_child("Visual", false, false) as Node3D
		checks["soul_starts_low"] = visual.position.y < -0.1
		await _seconds(soul.rise_s + 0.3)
		checks["soul_did_not_move"] = soul.global_position.is_equal_approx(before)
		checks["soul_risen"] = absf(visual.position.y) < 0.01
	corpse.dissolving = true
	checks["still_visible"] = mesh.transparency < 1.0
	await _seconds(look.corpse_fade_s + 0.3)
	checks["faded_out"] = is_equal_approx(mesh.transparency, 1.0)
	unit.free()
	return _verdict(checks)


## A doctor dies carrying a creature. Rule on: it dies in the air and its soul is where it landed. Rule off: it lands alive.
func _carrier(dies_when_dropped: bool) -> Dictionary:
	var rules := RULES.duplicate() as MatchRules
	rules.carried_dies_when_dropped = dies_when_dropped
	var unit := _unit("nmuh", Vector3(0.0, 0.0, 6.0))
	var doctor := DOCTOR_SCENE.instantiate() as DoctorBody
	doctor.owner_slot = 1
	doctor.rules = rules
	doctor.position = Vector3(0.0, 0.1, 0.0)
	_root.add_child(doctor)
	await _frames(20)
	var captive := Captive.of(unit)
	var checks := {"taken": captive.take(doctor)}
	await _until(func() -> bool: return unit.global_position.y > 2.0, GUARD_FRAMES)
	checks["hanging"] = unit.is_held() and unit.global_position.y > 2.0
	doctor.kill(2)
	if dies_when_dropped:
		var corpse := unit.corpse()
		await _until(func() -> bool: return corpse.is_settled, GUARD_FRAMES)
		await _frames(2)
		var soul := _soul_of(unit)
		checks["dead_on_floor"] = unit.is_dead() and unit.global_position.y < 0.5 and unit.is_in_group("corpse")
		checks["soul_where_it_landed"] = soul != null and soul.global_position.y < 2.5 and Vector2(soul.global_position.x - unit.global_position.x, soul.global_position.z - unit.global_position.z).length() < 1.0
	else:
		await _until(func() -> bool: return unit.global_position.y < 0.5 and unit.is_on_floor(), GUARD_FRAMES)
		await _frames(2)
		checks["alive_on_floor"] = not unit.is_dead() and unit.global_position.y < 0.5 and unit.is_in_group("unit")
		checks["no_soul"] = _soul_of(unit) == null
	unit.free()
	doctor.free()
	return _verdict(checks)


func _unit(tag: String, at: Vector3) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = 2
	unit.creature_tag = tag
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _soul_of(unit: Node) -> Soul:
	for node in _host.get_tree().get_nodes_in_group("soul"):
		var soul := node as Soul
		if soul != null and is_instance_valid(soul) and not soul.is_queued_for_deletion() and soul.corpse == unit:
			return soul
	return null


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


## Waits game seconds (the tweens of the look run on them).
func _seconds(seconds: float) -> void:
	await _host.get_tree().create_timer(seconds).timeout


## Waits until `condition` holds or `limit` frames pass. Returns the frames it took, or -1.
func _until(condition: Callable, limit: int) -> int:
	for frame in limit:
		if condition.call():
			return frame
		await _host.get_tree().physics_frame
	return 0 if condition.call() else -1


func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("death_cases: falla %s" % key)
	checks["ok"] = ok
	return checks
