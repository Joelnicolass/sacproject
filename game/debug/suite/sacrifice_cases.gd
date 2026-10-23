extends RefCounted

## RFC-020c cases of rules_suite: where the doctor drops (SacrificeMath), the creature a doctor holds
## (Captive) and what Desecrate accepts (SacrificeSystem + DesecrateAction). `run(host)` adds its own
## floor and bodies under `host` and removes them when it ends.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const DOCTOR_SCENE := preload("res://scenes/sacrifice/doctor.tscn")
const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "SacrificeCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 2.0, 600.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_host.add_child(_root)
	await _frames(2)
	var out := {}
	out["drop_positions"] = _drop_positions()
	out["captive"] = await _captive()
	out["desecrate_check"] = await _desecrate_check()
	_root.queue_free()
	return out


## The vortex hangs 20 m from the target on the wizard's side and the doctor lands halfway; with no
## ground at the landing the offset turns ±45°, ±90°, ±135°, 180°, and with none at all it falls back.
func _drop_positions() -> Dictionary:
	var checks := {}
	var target := Vector3(100.0, 3.0, 50.0)
	var caster := Vector3(0.0, 0.0, 50.0)
	var flat := SacrificeMath.drop_positions(target, caster, 20.0, func(_p: Vector3) -> bool: return true)
	checks["vortex_20m"] = is_equal_approx((flat["vortex"] as Vector3).distance_to(target), 20.0)
	checks["wizard_side"] = (flat["vortex"] as Vector3).x < target.x and is_equal_approx((flat["vortex"] as Vector3).x, 80.0)
	checks["landing_midpoint"] = (flat["landing"] as Vector3).is_equal_approx(0.5 * ((flat["vortex"] as Vector3) + target))
	checks["landing_10m"] = is_equal_approx((flat["landing"] as Vector3).distance_to(target), 10.0)
	checks["first_try"] = int(flat["step"]) == 0
	## Ground only at the n-th candidate: the angles come in the order of sacengine.
	var angles: Array[float] = []
	var toward := Vector3(-1.0, 0.0, 0.0)
	var seen := func(point: Vector3) -> bool:
		var landing_offset := (point - target) * 2.0
		angles.append(rad_to_deg(toward.signed_angle_to(Vector3(landing_offset.x, 0.0, landing_offset.z), Vector3.UP)))
		return false
	var none := SacrificeMath.drop_positions(target, caster, 20.0, seen)
	var expected: Array[float] = [0.0, 45.0, 45.0, 90.0, 90.0, 135.0, 135.0, 180.0]
	var order_ok := angles.size() == expected.size()
	for i in mini(angles.size(), expected.size()):
		order_ok = order_ok and absf(absf(angles[i]) - expected[i]) < 0.01
	checks["tries_8"] = angles.size() == 8
	checks["angle_order"] = order_ok
	checks["alternates_sides"] = angles.size() == 8 and signf(angles[1]) == -signf(angles[2]) and signf(angles[3]) == -signf(angles[4]) and signf(angles[5]) == -signf(angles[6])
	checks["fallback_lands_on_target"] = int(none["step"]) == -1 and (none["landing"] as Vector3).is_equal_approx(target)
	checks["fallback_vortex_10m"] = is_equal_approx((none["vortex"] as Vector3).distance_to(target), 10.0)
	var sideways := SacrificeMath.drop_positions(target, caster, 20.0, func(p: Vector3) -> bool: return absf(p.z - target.z) > 9.0)
	checks["ninety_degrees"] = int(sideways["step"]) == 2 and is_equal_approx(absf((sideways["landing"] as Vector3).z - target.z), 10.0)
	## Target on top of the caster: no direction, but a result.
	var on_top := SacrificeMath.drop_positions(caster, caster, 20.0, func(_p: Vector3) -> bool: return true)
	checks["no_direction_ok"] = (on_top["vortex"] as Vector3).is_finite()
	return _verdict(checks)


## A held creature leaves «unit», is not a target and takes no orders, follows the doctor hanging
## behind it, and let go is alive, with its owner and free again.
func _captive() -> Dictionary:
	var checks := {}
	var unit := _unit(Vector3(0.0, 0.1, 6.0), 1)
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	## The rule off: a dropped creature lands alive (MatchRules.carried_dies_when_dropped; on, it dies: death_cases).
	doctor.rules = RULES.duplicate() as MatchRules
	doctor.rules.carried_dies_when_dropped = false
	await _frames(20)
	var captive := Captive.of(unit)
	var health: Health = unit.get_node("Health")
	var before_layer := unit.collision_layer
	checks["has_captive"] = captive != null
	checks["free_before"] = unit.is_in_group("unit") and Attackable.is_body(unit) and unit.is_targetable()
	checks["taken"] = captive.take(doctor)
	checks["mode_held"] = unit.mode == UnitBody.Mode.HELD and unit.is_held()
	checks["left_unit"] = not unit.is_in_group("unit") and unit.is_in_group(Captive.HELD_GROUP)
	checks["not_a_target"] = not Attackable.is_body(unit) and not unit.is_targetable()
	checks["not_obstacle"] = not unit.is_obstacle()
	checks["no_collision"] = unit.collision_layer == 0
	checks["no_double_take"] = not captive.take(doctor)
	unit.begin_walk(Vector3(30.0, 0.0, 0.0))
	unit.engage(doctor)
	unit.halt()
	checks["no_orders"] = unit.mode == UnitBody.Mode.HELD
	unit.use_ability(Vector3.ZERO)
	checks["no_ability"] = unit.mode == UnitBody.Mode.HELD
	await _frames(120)
	var hang := Captive.hang_point(doctor.global_position, doctor.facing_flat(), RULES.carry_height, RULES.carry_distance)
	## sacengine only steps while farther than 0.75 m from the hang point.
	checks["hangs_behind_doctor"] = unit.global_position.distance_to(hang) <= 0.75
	checks["floats_3_5"] = absf((unit.global_position.y - doctor.global_position.y) - RULES.carry_height) < 0.3
	checks["behind"] = unit.global_position.z < doctor.global_position.z
	checks["alive_while_held"] = not health.is_dead() and unit.owner_slot == 1
	doctor.kill(2)
	await _frames(60)
	checks["freed_on_doctor_death"] = not unit.is_held() and unit.is_in_group("unit") and not unit.is_in_group(Captive.HELD_GROUP)
	checks["free_alive_same_owner"] = unit.mode != UnitBody.Mode.DEAD and not health.is_dead() and unit.owner_slot == 1
	checks["free_collision_back"] = unit.collision_layer == before_layer
	checks["free_is_target_again"] = Attackable.is_body(unit) and unit.is_targetable() and unit.is_obstacle()
	await _frames(120)
	checks["fell_to_ground"] = unit.global_position.y < 0.6
	unit.begin_walk(Vector3(30.0, 0.0, 6.0))
	checks["free_takes_orders"] = unit.mode == UnitBody.Mode.MOVE
	## Explicit release and a dead creature that cannot be taken.
	var doctor2 := _doctor(Vector3(10.0, 0.1, 0.0))
	await _frames(5)
	checks["retaken"] = captive.take(doctor2)
	captive.release()
	checks["explicit_release"] = not unit.is_held() and unit.is_in_group("unit")
	health.damage(99999.0, 2)
	await _frames(3)
	checks["dead_not_taken"] = not captive.take(doctor2)
	for node in [unit, doctor, doctor2]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


## Altar out of range / absent / collapsing, and the creature rules, through SacrificeSystem and the
## DesecrateAction of the wizard's book; then the cast: vortex while casting, none after an interruption.
func _desecrate_check() -> Dictionary:
	var checks := {}
	var system := SYSTEM_SCENE.instantiate() as SacrificeSystem
	system.rules = RULES
	_root.add_child(system)
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = Vector3.ZERO
	var action := wizard.get_node("Caster").action_for("ucas") as DesecrateAction
	var spell: SpellType = wizard.get_node("Spellbook").structure_by_tag("ucas")
	await _frames(2)
	checks["action_found"] = action != null and spell != null and action.pick == SpellAction.Pick.OWN_UNIT
	checks["action_no_warnings"] = action != null and action._get_configuration_warnings().is_empty()
	checks["spell_numbers"] = spell != null and is_equal_approx(spell.mana_cost, 1000.0) and absf(spell.casting_time_s - 5.5556) < 0.01 and is_equal_approx(spell.cast_range, 20.0)
	checks["no_altar"] = action.arm_status(wizard, spell) == SacrificeSystem.NO_ALTAR
	var far := _altar(2, Vector3(0.0, 0.0, 80.0))
	checks["altar_80_far"] = action.arm_status(wizard, spell) == SacrificeSystem.FAR_FROM_ALTAR
	far.free()
	var own := _altar(1, Vector3(0.0, 0.0, 30.0))
	checks["own_altar_not_enough"] = action.arm_status(wizard, spell) == SacrificeSystem.NO_ALTAR
	own.free()
	var near := _altar(2, Vector3(0.0, 0.0, 60.0))
	checks["altar_60_ok"] = action.arm_status(wizard, spell) == ""
	checks["closest_is_near"] = system.closest_enemy_altar(1, wizard.global_position, 75.0) == near
	var farther := _altar(2, Vector3(0.0, 0.0, -70.0))
	checks["closest_of_two"] = system.closest_enemy_altar(1, wizard.global_position, 75.0) == near
	farther.free()
	var offering := _unit(Vector3(0.0, 0.1, 12.0), 1)
	var enemy := _unit(Vector3(3.0, 0.1, 12.0), 2)
	var dead := _unit(Vector3(-3.0, 0.1, 12.0), 1)
	var distant := _unit(Vector3(0.0, 0.1, 25.0), 1)
	var held := _unit(Vector3(6.0, 0.1, 12.0), 1)
	var doctor := _doctor(Vector3(-6.0, 0.1, 12.0))
	doctor.owner_slot = 1
	await _frames(20)
	dead.get_node("Health").damage(99999.0, 2)
	await _frames(3)
	var holder := _doctor(Vector3(0.0, 0.1, -10.0))
	Captive.of(held).take(holder)
	checks["offering_ok"] = action.check(wizard, spell, Vector3.ZERO, offering, "").status == ""
	checks["offering_aim"] = action.check(wizard, spell, Vector3(999.0, 0.0, 999.0), offering, "").point.is_equal_approx(offering.global_position)
	checks["enemy_creature"] = action.check(wizard, spell, Vector3.ZERO, enemy, "").status == SpellAction.BAD_TARGET
	checks["dead_creature"] = action.check(wizard, spell, Vector3.ZERO, dead, "").status == SpellAction.BAD_TARGET
	checks["doctor_as_offering"] = action.check(wizard, spell, Vector3.ZERO, doctor, "").status == SpellAction.BAD_TARGET
	checks["wizard_as_offering"] = action.check(wizard, spell, Vector3.ZERO, wizard, "").status == SpellAction.BAD_TARGET
	checks["ground_as_offering"] = action.check(wizard, spell, Vector3(0.0, 0.0, 12.0), null, "").status == SpellAction.BAD_TARGET
	checks["already_held"] = action.check(wizard, spell, Vector3.ZERO, held, "").status == SpellAction.BAD_TARGET
	checks["out_of_range_25"] = action.check(wizard, spell, Vector3.ZERO, distant, "").status == SpellAction.OUT_OF_RANGE
	checks["no_mana"] = action.check(wizard, spell, Vector3.ZERO, offering, SpellAction.NO_MANA).status == SpellAction.NO_MANA
	checks["cooling"] = action.check(wizard, spell, Vector3.ZERO, offering, SpellAction.COOLING).status == SpellAction.COOLING
	## The cast: the vortex opens while casting and closes when interrupted; no doctor comes out.
	var aim := action.check(wizard, spell, Vector3.ZERO, offering, "")
	action.begin(wizard, spell, aim)
	await _frames(2)
	var vortices := system.get_node("Vortices")
	checks["vortex_while_casting"] = vortices.get_child_count() == 1
	var vortex := vortices.get_child(0) as RedVortex if vortices.get_child_count() > 0 else null
	checks["vortex_20m_from_offering"] = vortex != null and is_equal_approx(Vector2(vortex.global_position.x - offering.global_position.x, vortex.global_position.z - offering.global_position.z).length(), 20.0)
	checks["vortex_15m_up"] = vortex != null and is_equal_approx(vortex.global_position.y - offering.global_position.y, RULES.doctor_drop_height)
	action.cancel()
	await _frames(2)
	checks["vortex_gone_on_interrupt"] = vortices.get_child_count() == 0
	checks["no_doctor_on_interrupt"] = system.get_node("Doctors").get_child_count() == 0
	checks["offering_free_after_interrupt"] = offering.is_in_group("unit") and not offering.is_held()
	## It finishes: a carrier doctor falls and the vortex is gone.
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, offering, ""))
	var told := action.finish(wizard, spell, offering)
	await _frames(2)
	checks["finish_silent"] = told == ""
	checks["doctor_after_finish"] = system.get_node("Doctors").get_child_count() == 1
	checks["vortex_gone_on_finish"] = vortices.get_child_count() == 0
	var carrier := system.get_node("Doctors").get_child(0) as DoctorBody if system.get_node("Doctors").get_child_count() > 0 else null
	checks["doctor_falls"] = carrier != null and carrier.pose == DoctorBody.Pose.FALLING and carrier.owner_slot == 1
	checks["doctor_has_errand"] = carrier != null and carrier.get_node_or_null("Errand") is CarryErrand
	## The creature died during the cast: nothing comes out and the owner is told.
	if carrier != null:
		carrier.free()
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, offering, ""))
	offering.get_node("Health").damage(99999.0, 2)
	await _frames(2)
	checks["dead_in_cast_told"] = action.finish(wizard, spell, null) == SpellAction.BAD_TARGET
	checks["dead_in_cast_no_doctor"] = system.get_node("Doctors").get_child_count() == 0
	for node in [offering, enemy, dead, distant, held, doctor, holder, near, wizard, system]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.creature_tag = "nmuh"
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _doctor(at: Vector3) -> DoctorBody:
	var doctor := DOCTOR_SCENE.instantiate() as DoctorBody
	doctor.owner_slot = 2
	doctor.rules = RULES
	doctor.position = at
	_root.add_child(doctor)
	return doctor


func _altar(slot: int, at: Vector3) -> Altar:
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = slot
	altar.position = at
	_root.add_child(altar)
	return altar


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("sacrifice_cases: falla %s" % key)
	checks["ok"] = ok
	return checks
