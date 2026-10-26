extends RefCounted

## RFC-020e cases of rules_suite: the numbers of Convert (SacrificeMath), the corpse that stands up and
## dies again (Captive + Corpse), what Convert accepts (SacrificeSystem + ConvertAction) and the whole
## errand with a real doctor: it walks to the corpse, pumps, carries and the ritual ends in souls; and
## the four ways the doctor can die. `run(host)` adds its own floor and bodies under `host` and removes
## them when it ends. No network: the server paths run as solo.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const DOCTOR_SCENE := preload("res://scenes/sacrifice/doctor.tscn")
const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"
## Frames a scenario may take before it counts as stuck (60 per simulated second).
const GUARD_FRAMES := 5400

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "ConvertCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_host.add_child(_root)
	await _frames(2)
	var out := {}
	out["convert_numbers"] = _numbers()
	out["convert_revive"] = await _revive()
	out["convert_check"] = await _check()
	out["convert_chain"] = await _chain()
	out["convert_doctor_dies"] = await _doctor_dies()
	_root.queue_free()
	return out


## Pump `(souls + 1) * 5` s, the creature stands up with max(400, 50 %) (never above its maximum), the
## vortex of Convert hangs past the soul as seen from the wizard, a Convert lasts int(max/550) + 1 rounds.
func _numbers() -> Dictionary:
	var checks := {}
	checks["pump_0_souls"] = is_equal_approx(SacrificeMath.pump_seconds(0), 5.0)
	checks["pump_1_soul"] = is_equal_approx(SacrificeMath.pump_seconds(1), 10.0)
	checks["pump_3_souls"] = is_equal_approx(SacrificeMath.pump_seconds(3), 20.0)
	checks["pump_rule"] = is_equal_approx(SacrificeMath.pump_seconds(1, RULES.convert_pump_s_per_soul), 10.0)
	checks["revive_800"] = is_equal_approx(SacrificeMath.revive_health(800.0), 400.0)
	checks["revive_4500"] = is_equal_approx(SacrificeMath.revive_health(4500.0), 2250.0)
	checks["revive_500_floor"] = is_equal_approx(SacrificeMath.revive_health(500.0), 400.0)
	checks["revive_100_cap"] = is_equal_approx(SacrificeMath.revive_health(100.0), 100.0)
	checks["rule_numbers"] = is_equal_approx(SacrificeFacts.of_rules(RULES).pump_reach_m, 2.0) and is_equal_approx(RULES.convert_revive_min_health, 400.0) \
		and is_equal_approx(RULES.convert_revive_fraction, 0.5) and is_equal_approx(RULES.convert_health_per_round, 550.0)
	var target := Vector3(100.0, 3.0, 50.0)
	var caster := Vector3(0.0, 0.0, 50.0)
	var beyond := SacrificeMath.drop_positions(target, caster, 20.0, func(_p: Vector3) -> bool: return true, true)
	checks["vortex_past_soul"] = is_equal_approx((beyond["vortex"] as Vector3).x, 120.0)
	checks["vortex_20m"] = is_equal_approx((beyond["vortex"] as Vector3).distance_to(target), 20.0)
	checks["landing_10m_past"] = is_equal_approx((beyond["landing"] as Vector3).x, 110.0)
	var near := SacrificeMath.drop_positions(target, caster, 20.0, func(_p: Vector3) -> bool: return true)
	checks["desecrate_unchanged"] = is_equal_approx((near["vortex"] as Vector3).x, 80.0)
	return _verdict(checks)


## A corpse revived stands up with 400 of 800, is nobody's target, a doctor can take it, it is released
## alive and with its owner; killed again it is a corpse and leaves a soul of its owner's side.
func _revive() -> Dictionary:
	var checks := {}
	var souls := SOUL_SYSTEM_SCENE.instantiate()
	_root.add_child(souls)
	var unit := _unit(Vector3(0.0, 0.1, 10.0), 2)
	var doctor := _doctor(Vector3(0.0, 0.1, 0.0))
	await _frames(20)
	var captive := Captive.of(unit)
	var health: Health = unit.get_node("Health")
	var corpse := unit.get_node("Corpse")
	checks["alive_cannot_revive"] = not captive.revive(400.0, 0.5)
	health.damage(99999.0, 1)
	await _frames(120)
	checks["dead"] = unit.is_dead() and unit.is_in_group("corpse") and corpse.laid and corpse.is_settled
	var first := _soul_of(unit)
	checks["soul_dropped"] = first != null and first.owner_slot == 2 and first.attached
	checks["red_for_slot_1"] = first != null and first.color_for(1) == Soul.SoulColor.RED
	checks["blue_for_owner"] = first != null and first.color_for(2) == Soul.SoulColor.BLUE
	## A soul still growing in can already be converted (the PTNET Convert on a fresh Cog soul answered bad_target).
	checks["emerging_convertible_by_1"] = first != null and first.state == Soul.State.EMERGING and first.can_convert_by(1)
	await _until(func() -> bool: return first != null and first.state == Soul.State.NORMAL, 400)
	checks["convertible_by_1"] = first != null and first.can_convert_by(1)
	first.reserve_for(1)
	checks["reserved_for_1_only"] = not first.can_convert_by(1) and first.is_reserved_for(1) and not first.is_reserved_for(3)
	first.release_for(1)
	checks["released_convertible"] = first.can_convert_by(1)
	## It stands up.
	checks["revive_ok"] = captive.revive(RULES.convert_revive_min_health, RULES.convert_revive_fraction)
	checks["mode_reviving"] = unit.mode == UnitBody.Mode.REVIVING and unit.is_reviving() and unit.is_taken()
	checks["health_400_of_800"] = is_equal_approx(health.current, 400.0) and is_equal_approx(health.maximum, 800.0) and not health.is_dead()
	checks["not_a_corpse_any_more"] = not unit.is_in_group("corpse") and not corpse.laid and not corpse.is_settled
	checks["left_the_unit_group"] = not unit.is_in_group("unit") and unit.is_in_group(Captive.HELD_GROUP)
	checks["not_a_target"] = not Attackable.is_body(unit) and not unit.is_targetable()
	checks["no_collision"] = unit.collision_layer == 0
	checks["not_obstacle"] = not unit.is_obstacle()
	checks["no_damage_taken"] = health.damage_typed(500.0, Health.MELEE, 1) == 0.0 and is_equal_approx(health.current, 400.0)
	unit.begin_walk(Vector3(30.0, 0.0, 6.0))
	unit.halt()
	checks["no_orders"] = unit.mode == UnitBody.Mode.REVIVING
	checks["no_second_revive"] = not captive.revive(400.0, 0.5)
	await _frames(70)
	## What Pump does with the soul that was on the corpse: hidden while pumping, gone when it ends.
	first.state = Soul.State.REVIVING
	first.queue_free()
	checks["pivot_upright"] = (unit.get_node("Tilt") as Node3D).rotation.is_equal_approx(Vector3.ZERO)
	## The doctor takes it from REVIVING.
	checks["taken_from_reviving"] = captive.take(doctor)
	checks["mode_held"] = unit.mode == UnitBody.Mode.HELD and unit.is_held() and unit.is_taken()
	checks["let_go_alive_owner"] = _let_go(captive, unit)
	await _frames(3)
	checks["free_again"] = unit.is_in_group("unit") and not unit.is_in_group(Captive.HELD_GROUP) and unit.collision_layer == unit.unit_layer and unit.is_targetable()
	checks["same_owner_alive"] = unit.owner_slot == 2 and not health.is_dead() and health.current >= 400.0
	## Dies again from REVIVING: a corpse, and a new soul of its owner's side.
	health.damage(99999.0, 1)
	await _frames(120)
	var old := _soul_of(unit)
	checks["dead_once_more"] = unit.is_dead() and unit.is_in_group("corpse")
	checks["dead_again_soul"] = old != null and old != first and old.owner_slot == 2 and old.attached
	checks["revive_again_ok"] = captive.revive(400.0, 0.5)
	if old != null:
		old.state = Soul.State.REVIVING
		old.queue_free()
	captive.release(Captive.Release.CARRIER_DIED)
	await _frames(120)
	var again := _soul_of(unit)
	checks["die_again_dead"] = unit.is_dead() and unit.is_in_group("corpse") and not unit.is_in_group(Captive.HELD_GROUP) and unit.collision_layer == int(corpse.corpse_layer)
	checks["die_again_soul_side"] = again != null and again.owner_slot == 2 and again.attached and again.color_for(1) == Soul.SoulColor.RED
	checks["reviving_soul_hidden_not_collectable"] = old == null or not is_instance_valid(old) or not old.can_be_collected_by(1)
	for node in [unit, doctor, souls]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


## ConvertAction through the wizard's book: needs an own altar standing, a red soul (not blue, not
## reserved, not of a live creature) within 20 m; the vortex opens past the soul; the cast fixes the altar
## and reserves the soul; an interrupted cast frees it and no doctor comes out.
func _check() -> Dictionary:
	var checks := {}
	var system := SYSTEM_SCENE.instantiate() as SacrificeSystem
	system.rules = RULES
	_root.add_child(system)
	var souls := SOUL_SYSTEM_SCENE.instantiate()
	_root.add_child(souls)
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = Vector3(0.0, 0.0, 0.0)
	var action := wizard.get_node("Caster").action_for("ccas") as ConvertAction
	var spell: SpellType = wizard.get_node("Spellbook").structure_by_tag("ccas")
	await _frames(2)
	checks["action_found"] = action != null and spell != null and action.pick == SpellAction.Pick.SOUL
	checks["action_no_warnings"] = action != null and action._get_configuration_warnings().is_empty()
	checks["spell_numbers"] = spell != null and is_equal_approx(spell.mana_cost, 800.0) and absf(spell.casting_time_s - 2.2222) < 0.01 and is_equal_approx(spell.cast_range_m, 20.0)
	checks["no_altar"] = action.arm_status(wizard, spell) == SacrificeSystem.NO_ALTAR
	var enemy_altar := _altar(2, Vector3(0.0, 0.0, 40.0))
	checks["enemy_altar_not_enough"] = action.arm_status(wizard, spell) == SacrificeSystem.NO_ALTAR
	enemy_altar.free()
	var far_own := _altar(1, Vector3(0.0, 0.0, -300.0))
	checks["own_altar_any_distance"] = action.arm_status(wizard, spell) == ""
	var own := _altar(1, Vector3(0.0, 0.0, 60.0))
	checks["closest_own_site"] = system.closest_own_site(1, wizard.global_position) == own.site
	far_own.free()
	var enemy := _unit(Vector3(0.0, 0.1, 12.0), 2)
	var friend := _unit(Vector3(4.0, 0.1, 12.0), 1)
	var alive := _unit(Vector3(-4.0, 0.1, 12.0), 2)
	var distant := _unit(Vector3(0.0, 0.1, 30.0), 2)
	await _frames(20)
	for body in [enemy, friend, distant]:
		body.get_node("Health").damage(99999.0, 3)
	await _frames(120)
	var red := _soul_of(enemy)
	var blue := _soul_of(friend)
	var far_soul := _soul_of(distant)
	await _until(func() -> bool: return red != null and blue != null and far_soul != null and red.state == Soul.State.NORMAL and blue.state == Soul.State.NORMAL and far_soul.state == Soul.State.NORMAL, 400)
	checks["red_soul_ok"] = action.check(wizard, spell, Vector3.ZERO, red, "").status == ""
	checks["aim_is_the_soul"] = action.check(wizard, spell, Vector3(999.0, 0.0, 999.0), red, "").point.is_equal_approx(red.global_position)
	checks["own_soul_rejected"] = action.check(wizard, spell, Vector3.ZERO, blue, "").status == SpellAction.BAD_TARGET
	checks["live_creature_rejected"] = action.check(wizard, spell, Vector3.ZERO, alive, "").status == SpellAction.BAD_TARGET
	checks["ground_rejected"] = action.check(wizard, spell, Vector3.ZERO, null, "").status == SpellAction.BAD_TARGET
	checks["wizard_rejected"] = action.check(wizard, spell, Vector3.ZERO, wizard, "").status == SpellAction.BAD_TARGET
	checks["out_of_range"] = action.check(wizard, spell, Vector3.ZERO, far_soul, "").status == SpellAction.OUT_OF_RANGE
	checks["no_mana"] = action.check(wizard, spell, Vector3.ZERO, red, SpellAction.NO_MANA).status == SpellAction.NO_MANA
	checks["cooling"] = action.check(wizard, spell, Vector3.ZERO, red, SpellAction.COOLING).status == SpellAction.COOLING
	## The cast: vortex past the soul, soul reserved, altar fixed.
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, red, ""))
	await _frames(2)
	var vortices := system.get_node("Vortices")
	var vortex := vortices.get_child(0) as RedVortex if vortices.get_child_count() > 0 else null
	checks["vortex_while_casting"] = vortices.get_child_count() == 1
	checks["vortex_past_the_soul"] = vortex != null and vortex.global_position.z > red.global_position.z + 19.0
	checks["vortex_15m_up"] = vortex != null and absf((vortex.global_position.y - red.global_position.y) - SacrificeFacts.of_rules(RULES).drop_up_m) < 0.01
	checks["soul_reserved"] = red.is_reserved_for(1) and not red.can_convert_by(1)
	checks["reserved_rejected"] = action.check(wizard, spell, Vector3.ZERO, red, "").status == SpellAction.BAD_TARGET
	action.cancel()
	await _frames(2)
	checks["vortex_gone_on_interrupt"] = vortices.get_child_count() == 0
	checks["no_doctor_on_interrupt"] = system.get_node("Doctors").get_child_count() == 0
	checks["soul_free_after_interrupt"] = not red.is_reserved_for(1) and red.can_convert_by(1)
	## It finishes: a carrier with a Convert errand falls.
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, red, ""))
	var told := action.finish(wizard, spell, red)
	await _frames(2)
	checks["finish_silent"] = told == ""
	var carrier := system.get_node("Doctors").get_child(0) as DoctorBody if system.get_node("Doctors").get_child_count() > 0 else null
	var errand := carrier.get_node_or_null("Errand") as CarryErrand if carrier != null else null
	checks["carrier_falls"] = carrier != null and carrier.pose == DoctorBody.Pose.FALLING and carrier.owner_slot == 1
	checks["errand_is_convert"] = errand != null and errand.kind == Ritual.Kind.CONVERT and errand.soul == red and errand.creature == enemy and errand.creature_owner == 2
	checks["errand_site_is_own_altar"] = errand != null and errand.site == own.site
	checks["steps_have_pump"] = errand != null and errand.steps.get_node_or_null("Pump") != null
	if carrier != null:
		carrier.free()
	red.release_for(1)
	## The altar fell during the cast: no doctor, soul free.
	action.begin(wizard, spell, action.check(wizard, spell, Vector3.ZERO, red, ""))
	own.state = Altar.State.DESTROYED
	checks["altar_lost_in_cast_told"] = action.finish(wizard, spell, red) == SacrificeSystem.NO_ALTAR
	checks["altar_lost_no_doctor"] = system.get_node("Doctors").get_child_count() == 0
	checks["altar_lost_soul_free"] = not red.is_reserved_for(1)
	for node in [enemy, friend, alive, distant, wizard, own, system, souls]:
		if is_instance_valid(node):
			node.free()
	return _verdict(checks)


## The whole errand with a real doctor: it drops, walks to the corpse, pumps 10 s, takes the revived
## creature to the own altar and a ritual of Convert (2 rounds for 800 of life) turns it into 1 soul.
func _chain() -> Dictionary:
	var checks := {}
	var scene := await _scenario()
	var wizard: WizardBody = scene["wizard"]
	var system: SacrificeSystem = scene["system"]
	var victim: UnitBody = scene["victim"]
	var altar: Altar = scene["altar"]
	var soul: Soul = scene["soul"]
	var purse := wizard.get_node("SoulPurse")
	var before: int = purse.count
	var told := _cast(scene)
	checks["cast_silent"] = told == ""
	var seen := {}
	var started_msec := Time.get_ticks_msec()
	var frames := 0
	var ritual: Ritual = null
	var pump_frames := 0
	var phases: Array[int] = []
	while frames < GUARD_FRAMES:
		await _frames(1)
		frames += 1
		if not is_instance_valid(victim):
			seen["victim_freed"] = true
		elif victim.is_reviving():
			seen["reviving"] = true
			pump_frames += 1
			seen["reviving_health"] = (victim.get_node("Health") as Health).current
			seen["soul_state_while_pumping"] = soul.state if is_instance_valid(soul) else -1
		if is_instance_valid(victim) and victim.is_held():
			seen["held"] = true
		if ritual == null and system.get_node("Rituals").get_child_count() > 0:
			ritual = system.get_node("Rituals").get_child(0) as Ritual
			seen["ritual_kind"] = ritual.kind
			seen["doctors_at_ritual"] = ritual.doctors.size()
			seen["target_wizard_null"] = ritual.target_wizard == null
		if ritual != null and is_instance_valid(ritual):
			if phases.is_empty() or phases[-1] != ritual.phase:
				phases.append(ritual.phase)
			if ritual.outcome != Ritual.Outcome.RUNNING:
				seen["outcome"] = ritual.outcome
				seen["round_at_end"] = ritual.round_index
				break
	var pump_s := float(pump_frames) / 60.0
	print("convert_chain: %d cuadros (%.1f s simulados), bombeo %.1f s, fases %s, ronda final %s, %d ms" % [
		frames, frames / 60.0, pump_s, str(phases), str(seen.get("round_at_end", -1)), Time.get_ticks_msec() - started_msec])
	checks["pumped"] = bool(seen.get("reviving", false))
	checks["pump_10s"] = absf(pump_s - 10.0) < 0.5
	checks["revived_400"] = is_equal_approx(float(seen.get("reviving_health", 0.0)), 400.0)
	checks["soul_hidden_while_pumping"] = int(seen.get("soul_state_while_pumping", -1)) == Soul.State.REVIVING
	checks["carried"] = bool(seen.get("held", false))
	checks["ritual_started"] = ritual != null
	checks["ritual_is_convert"] = int(seen.get("ritual_kind", -1)) == Ritual.Kind.CONVERT
	checks["four_doctors"] = int(seen.get("doctors_at_ritual", 0)) == 4
	checks["no_target_wizard"] = bool(seen.get("target_wizard_null", false))
	checks["phases_in_order"] = phases.size() >= 5 and phases.slice(0, 5) == [Ritual.Phase.SETUP, Ritual.Phase.WALK, Ritual.Phase.SHOOT, Ritual.Phase.WAIT, Ritual.Phase.WALK]
	checks["completed"] = int(seen.get("outcome", -1)) == Ritual.Outcome.COMPLETED
	checks["two_rounds_for_800"] = int(seen.get("round_at_end", -1)) == 1
	await _frames(10)
	checks["souls_added"] = purse.count == before + 1
	checks["creature_gone"] = not is_instance_valid(victim) or victim.is_queued_for_deletion()
	checks["soul_gone"] = not is_instance_valid(soul) or soul.is_queued_for_deletion()
	checks["altar_standing"] = altar.is_standing()
	checks["site_free"] = altar.site.is_free()
	checks["wizard_untouched"] = not (wizard.health as Health).is_dead()
	_clear(scene)
	return _verdict(checks)


## The doctor dies before it arrives (the soul is red and convertible again), while it pumps (the
## corpse dies again and the soul is back, on its side) and while it carries (the creature falls alive,
## its original owner's).
func _doctor_dies() -> Dictionary:
	var checks := {}
	## Before it arrives.
	var scene := await _scenario()
	var victim: UnitBody = scene["victim"]
	var soul: Soul = scene["soul"]
	var wizard: WizardBody = scene["wizard"]
	_cast(scene)
	var doctor := await _carrier(scene, 120)
	checks["before_doctor_found"] = doctor != null
	var errand := doctor.get_node("Errand") as CarryErrand if doctor != null else null
	checks["before_reserved_during_trip"] = soul.is_reserved_for(1) and not soul.can_convert_by(1)
	if doctor != null:
		await _until(func() -> bool: return doctor.pose == DoctorBody.Pose.WALKING, 600)
		doctor.kill(2)
	await _frames(5)
	checks["before_soul_still_there"] = is_instance_valid(soul) and soul.state == Soul.State.NORMAL and soul.attached
	checks["before_soul_convertible"] = is_instance_valid(soul) and soul.can_convert_by(1)
	checks["before_corpse_dead"] = victim.is_dead() and victim.is_in_group("corpse")
	checks["before_errand_failed"] = errand != null
	_clear(scene)
	## While it pumps.
	scene = await _scenario()
	victim = scene["victim"]
	soul = scene["soul"]
	wizard = scene["wizard"]
	_cast(scene)
	doctor = await _carrier(scene, 120)
	var pumping := await _until(func() -> bool: return victim.is_reviving(), GUARD_FRAMES)
	checks["pump_started"] = pumping >= 0
	await _frames(120)
	checks["pump_still_going"] = victim.is_reviving() and (not is_instance_valid(soul) or soul.state == Soul.State.REVIVING)
	if doctor != null:
		doctor.kill(2)
	await _frames(150)
	checks["pump_creature_dies_again"] = victim.is_dead() and victim.is_in_group("corpse") and not victim.is_in_group(Captive.HELD_GROUP)
	var back := _soul_of(victim)
	checks["pump_soul_back"] = back != null and back.owner_slot == 2 and back.attached and back.color_for(1) == Soul.SoulColor.RED
	checks["pump_one_soul_only"] = _souls_of(victim).size() == 1
	_clear(scene)
	## While it carries.
	scene = await _scenario()
	victim = scene["victim"]
	soul = scene["soul"]
	wizard = scene["wizard"]
	var purse := wizard.get_node("SoulPurse")
	var before: int = purse.count
	_cast(scene)
	doctor = await _carrier(scene, 120)
	var carried := await _until(func() -> bool: return victim.is_held(), GUARD_FRAMES)
	checks["carry_started"] = carried >= 0
	await _frames(180)
	checks["carry_still_held"] = victim.is_held() and victim.global_position.y > 2.0
	if doctor != null:
		doctor.kill(2)
	await _frames(240)
	## MatchRules.carried_dies_when_dropped is on: it dies in the air, falls and its soul stays where it landed.
	checks["carry_creature_dead"] = victim.is_dead() and victim.mode != UnitBody.Mode.HELD and victim.corpse().is_settled
	checks["carry_original_owner"] = victim.owner_slot == 2
	checks["carry_is_corpse"] = victim.is_in_group("corpse") and not victim.is_in_group(Captive.HELD_GROUP)
	checks["carry_fell_to_floor"] = victim.global_position.y < 1.0
	var landed := _soul_of(victim)
	checks["carry_soul_where_it_landed"] = landed != null and landed.global_position.y < 2.0
	checks["carry_no_souls_for_caster"] = purse.count == before
	checks["carry_site_free"] = (scene["altar"] as Altar).site.is_free()
	_clear(scene)
	return _verdict(checks)


# --- Scenario ---

## A wizard of slot 1, his altar 70 m away, a Druid of slot 2 killed 14 m in front of him and its red soul
## ready to convert. Returns the nodes by name.
func _scenario() -> Dictionary:
	var system := SYSTEM_SCENE.instantiate() as SacrificeSystem
	system.rules = RULES
	_root.add_child(system)
	var souls := SOUL_SYSTEM_SCENE.instantiate()
	_root.add_child(souls)
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = Vector3.ZERO
	var altar := _altar(1, Vector3(0.0, 0.0, -70.0))
	var victim := _unit(Vector3(0.0, 0.1, 14.0), 2)
	await _frames(20)
	victim.get_node("Health").damage(99999.0, 1)
	await _frames(120)
	var soul := _soul_of(victim)
	await _until(func() -> bool: return soul != null and soul.state == Soul.State.NORMAL, 400)
	return {"system": system, "souls": souls, "wizard": wizard, "altar": altar, "victim": victim, "soul": soul}


func _cast(scene: Dictionary) -> String:
	var wizard: WizardBody = scene["wizard"]
	var soul: Soul = scene["soul"]
	var action := wizard.get_node("Caster").action_for("ccas") as ConvertAction
	var spell: SpellType = wizard.get_node("Spellbook").structure_by_tag("ccas")
	var aim := action.check(wizard, spell, Vector3.ZERO, soul, "")
	if not aim.status.is_empty():
		return aim.status
	action.begin(wizard, spell, aim)
	return action.finish(wizard, spell, soul)


## The carrier doctor of the scenario, waiting up to `frames` for it to exist.
func _carrier(scene: Dictionary, frames: int) -> DoctorBody:
	var system: SacrificeSystem = scene["system"]
	await _until(func() -> bool: return system.get_node("Doctors").get_child_count() > 0, frames)
	return system.get_node("Doctors").get_child(0) as DoctorBody if system.get_node("Doctors").get_child_count() > 0 else null


func _clear(scene: Dictionary) -> void:
	for key in ["victim", "wizard", "altar", "system", "souls"]:
		var node: Variant = scene.get(key)
		if node != null and is_instance_valid(node):
			(node as Node).free()
	for node in _root.get_children():
		if node is DoctorBody or node is Soul or node is UnitBody:
			node.free()


func _let_go(captive: Captive, unit: UnitBody) -> bool:
	captive.release()
	return unit.mode != UnitBody.Mode.HELD and not unit.is_dead() and unit.owner_slot == 2


func _soul_of(unit: Node) -> Soul:
	var found := _souls_of(unit)
	return found[0] if not found.is_empty() else null


func _souls_of(unit: Node) -> Array[Soul]:
	var found: Array[Soul] = []
	for node in _host.get_tree().get_nodes_in_group("soul"):
		var soul := node as Soul
		if soul != null and is_instance_valid(soul) and not soul.is_queued_for_deletion() and soul.corpse == unit:
			found.append(soul)
	return found


func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = GameData.creature("nmuh")
	unit.model = type.model_id() if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _doctor(at: Vector3) -> DoctorBody:
	var doctor := DOCTOR_SCENE.instantiate() as DoctorBody
	doctor.owner_slot = 1
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
			print("convert_cases: falla %s" % key)
	checks["ok"] = ok
	return checks
