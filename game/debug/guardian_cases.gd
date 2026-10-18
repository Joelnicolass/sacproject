extends RefCounted

## RFC-021b cases of rules_suite: the damage split among a building's guardians (GuardPost), what a
## guardian gains (GuardianBond: factors, heal, lost ability, rooted), the leash, every way the bond
## ends, what GuardianAction accepts and how the selection treats a guardian. No network: the server
## paths run as solo. `run(host)` adds its own floor and bodies under `host` and removes them at the end.

const UNIT_SCENE := preload("res://scenes/world/units/unit.tscn")
const STRUCTURE_SCENE := preload("res://scenes/world/structures/structure.tscn")
const ALTAR_SCENE := preload("res://scenes/world/props/altar.tscn")
const WIZARD_SCENE := preload("res://scenes/world/wizard/wizard_body.tscn")
const SELECTION := preload("res://scenes/world/selection.gd")
const RULES := preload("res://data/match_rules.tres")
const GOD := "james"
const TAG := "nmuh"

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "GuardianCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 2.0, 1200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_host.add_child(_root)
	await _frames(2)
	var out := {}
	out["guard_split"] = await _split()
	out["guard_drain"] = await _drain()
	out["guard_fire"] = await _fire()
	out["guard_factors"] = await _factors()
	out["guard_leash"] = await _leash()
	out["guard_release"] = await _release()
	out["guard_action"] = await _action()
	out["guard_selection"] = await _selection()
	_root.queue_free()
	return out


## n = 1..5: the building takes nothing and each guardian takes damage / min(n, 0.5 (n + 3)) with its own
## resistance (state.d:9098-9117); with no valid guardian the building takes the hit itself.
func _split() -> Dictionary:
	var checks := {}
	var expected := [1.0, 2.0, 3.0, 3.5, 4.0]
	var divisors_ok := true
	for n in range(1, 6):
		divisors_ok = divisors_ok and is_equal_approx(GuardPost.split_divisor(n), expected[n - 1])
	checks["divisors"] = divisors_ok
	var structure := _structure(Vector3.ZERO)
	var health := structure.get_node("Health") as Health
	await _frames(2)
	var before := health.current
	health.damage_typed(60.0, Health.MELEE, 2)
	checks["no_guard_building_takes"] = health.current < before
	for n in range(1, 6):
		health.current = health.maximum
		var guards: Array[UnitBody] = []
		for i in n:
			var unit := _unit(Vector3(10.0 + 3.0 * i, 0.0, 10.0), 1)
			await _frames(1)
			guards.append(unit)
			GuardianBond.of(unit).bind(_post(structure))
		var kept := health.current
		var taken_sum := health.damage_typed(60.0, Health.MELEE, 2)
		checks["n%d_building_untouched" % n] = is_equal_approx(health.current, kept)
		var per_guard_ok := true
		for unit in guards:
			var unit_health := unit.get_node("Health") as Health
			var lost := unit_health.maximum - unit_health.current
			per_guard_ok = per_guard_ok and absf(lost - 60.0 / expected[n - 1] * unit_health.resistance(Health.MELEE)) < 0.01
		checks["n%d_share" % n] = per_guard_ok
		checks["n%d_returns_total" % n] = absf(taken_sum - 60.0 / expected[n - 1] * guards[0].get_node("Health").resistance(Health.MELEE) * n) < 0.05
		for unit in guards:
			unit.queue_free()
		await _frames(2)
	checks["empty_again"] = _post(structure).guard_count() == 0
	var ground := health.current
	health.damage_typed(60.0, Health.MELEE, 2)
	checks["after_all_gone_building_takes"] = health.current < ground
	structure.queue_free()
	return _verdict("guard_split", checks)


## F164b: a hit a building's guardians take drains the attacker from what THEY took (damageGuardians -> the creature overload of
## dealDamage, state.d:9119-9141, 8933-8947); with no valid guardian the building takes it and nothing drains (9193-9207).
func _drain() -> Dictionary:
	var checks := {}
	var structure := _structure(Vector3.ZERO)
	var health := structure.get_node("Health") as Health
	var scythe := _unit(Vector3(40.0, 0.0, 10.0), 2, "dzid")
	await _frames(2)
	var feeder := scythe.get_node("Health") as Health
	var drain := scythe.type.drain
	checks["scythe_drains"] = drain > 0.0
	feeder.current = feeder.maximum * 0.5
	var start := feeder.current
	var taken := health.damage_typed(60.0, Health.MELEE, 2)
	checks["unguarded_building_takes"] = taken > 0.0 and not health.deflected_last
	checks["unguarded_building_no_drain"] = is_zero_approx(LifeDrain.feed(scythe, structure, taken)) and is_equal_approx(feeder.current, start)
	var guards: Array[UnitBody] = []
	for i in 2:
		var unit := _unit(Vector3(10.0 + 3.0 * i, 0.0, 10.0), 1)
		await _frames(1)
		guards.append(unit)
		GuardianBond.of(unit).bind(_post(structure))
	taken = health.damage_typed(60.0, Health.MELEE, 2)
	var want: float = 60.0 / GuardPost.split_divisor(2) * guards[0].get_node("Health").resistance(Health.MELEE) * 2.0
	checks["guarded_hit_deflects"] = health.deflected_last and absf(taken - want) < 0.05
	var gained := LifeDrain.feed(scythe, structure, taken)
	checks["guarded_drain_from_guardians"] = absf(gained - drain * taken) < 0.001 and absf(feeder.current - (start + drain * taken)) < 0.001
	var melee := health.damage(60.0, 2)  ## the melee path reports it too (MeleeAttack._land feeds with this)
	checks["melee_reports_guardians_damage"] = health.deflected_last and melee > 0.0
	taken = health.damage_typed(60.0, Health.MELEE, 2)
	for unit in guards:
		_post(structure).unbind(GuardianBond.of(unit))
	var after := health.damage_typed(60.0, Health.MELEE, 2)
	checks["unbound_building_takes_again"] = after > 0.0 and not health.deflected_last
	for unit in guards:
		unit.queue_free()
	scythe.queue_free()
	structure.queue_free()
	await _frames(2)
	return _verdict("guard_drain", checks)


## F164c / F162b: a Burning drains its attacker from what each update took (dealFireDamage -> dealDamage with the attacker,
## state.d:9421-9427, 8940), and a fire of no damage on a building is made and ends on its first update (updateFire 15117-15118).
func _fire() -> Dictionary:
	var checks := {}
	var structure := _structure(Vector3.ZERO)
	var scythe := _unit(Vector3(40.0, 0.0, 10.0), 2, "dzid")
	var victim := _unit(Vector3(10.0, 0.0, 10.0), 1)
	await _frames(2)
	var feeder := scythe.get_node("Health") as Health
	feeder.current = feeder.maximum * 0.5
	var start := feeder.current
	var burn := Burning.ignite(victim, 120.0, 60, Health.DIRECT_RANGED, 2, 0.0, false, "", scythe)
	checks["fire_made"] = burn != null
	if burn != null:
		burn.set_physics_process(false)
		checks["fire_keeps_attacker"] = burn.attacker_path == scythe.get_path()
		var health := victim.get_node("Health") as Health
		var before := health.current
		burn.step(health)
		var took := before - health.current
		checks["fire_took"] = took > 0.0
		checks["fire_drains"] = absf(feeder.current - (start + took * scythe.type.drain)) < 0.001
	var mid := feeder.current
	var anon := Burning.ignite(victim, 120.0, 60, Health.DIRECT_RANGED, 2)
	if anon != null:
		anon.set_physics_process(false)
		anon.step(victim.get_node("Health") as Health)
	checks["fire_without_attacker_no_drain"] = anon != null and anon.attacker_path.is_empty() and is_equal_approx(feeder.current, mid)
	var building := Burning.ignite(structure, 0.0, 30, Health.DIRECT_RANGED, 2, 0.0, false, "", scythe)
	checks["building_fire_made"] = building != null
	if building != null:
		building.set_physics_process(false)
		var structure_health := structure.get_node("Health") as Health
		var hp := structure_health.current
		var going := building.step(structure_health)
		checks["building_fire_ends_first_update"] = not going and building.updates == 1 and is_equal_approx(structure_health.current, hp)
		checks["building_fire_no_drain"] = is_equal_approx(feeder.current, mid)
	for node in [victim, scythe, structure]:
		node.queue_free()
	await _frames(2)
	return _verdict("guard_fire", checks)


## Attack ×1.5, spells ×0.5, ranged ×0.25, melee unchanged, heal 16.667/s on top of regeneration, no active
## ability, group `rooted`; released, everything goes back.
func _factors() -> Dictionary:
	var checks := {}
	var structure := _structure(Vector3.ZERO)
	var guard := _unit(Vector3(20.0, 0.0, 0.0), 1)
	var twin := _unit(Vector3(-20.0, 0.0, 0.0), 1)
	await _frames(3)
	var bond := GuardianBond.of(guard)
	var gh := guard.get_node("Health") as Health
	var th := twin.get_node("Health") as Health
	checks["free_defaults"] = guard.attack_factor == 1.0 and not bond.is_bound() and not guard.is_in_group("rooted") and gh.kind_factors.is_empty()
	checks["bind"] = bond.bind(_post(structure)) and bond.is_bound() and guard.is_in_group("rooted")
	checks["bind_twice_refused"] = not bond.bind(_post(structure))
	checks["attack_factor"] = is_equal_approx(guard.attack_factor, RULES.guardian_attack_factor) and is_equal_approx(RULES.guardian_attack_factor, 1.5)
	var melee_free := th.damage_typed(10.0, Health.MELEE, 2)
	var melee_guard := gh.damage_typed(10.0, Health.MELEE, 2)
	checks["melee_unchanged"] = absf(melee_free - melee_guard) < 0.001
	th.current = th.maximum
	gh.current = gh.maximum
	var spell_free := th.damage_typed(10.0, Health.DIRECT_SPELL, 2)
	var spell_guard := gh.damage_typed(10.0, Health.DIRECT_SPELL, 2)
	var splash_guard := gh.damage_typed(10.0, Health.SPLASH_SPELL, 2)
	var splash_free := th.damage_typed(10.0, Health.SPLASH_SPELL, 2)
	checks["spell_half"] = spell_free > 0.0 and absf(spell_guard - 0.5 * spell_free) < 0.001 and absf(splash_guard - 0.5 * splash_free) < 0.001
	var shot_free := th.damage_typed(10.0, Health.DIRECT_RANGED, 2)
	var shot_guard := gh.damage_typed(10.0, Health.DIRECT_RANGED, 2)
	var shot_splash_free := th.damage_typed(10.0, Health.SPLASH_RANGED, 2)
	var shot_splash_guard := gh.damage_typed(10.0, Health.SPLASH_RANGED, 2)
	checks["ranged_quarter"] = shot_free > 0.0 and absf(shot_guard - 0.25 * shot_free) < 0.001 and absf(shot_splash_guard - 0.25 * shot_splash_free) < 0.001
	var ability := guard.get_node("ActiveAbility") as ActiveAbility
	checks["ability_locked"] = ability.locked and ability.status(guard.global_position, null) == ActiveAbility.NO_ABILITY
	checks["twin_ability_free"] = not (twin.get_node("ActiveAbility") as ActiveAbility).locked
	gh.current = gh.maximum * 0.5
	th.current = th.maximum * 0.5
	await _frames(60)
	var extra := (gh.current - th.current)
	checks["heal_per_second"] = absf(extra - RULES.guardian_heal_per_s) < 0.8
	checks["heal_rule"] = absf(RULES.guardian_heal_per_s - 1000.0 / 60.0) < 0.001
	bond.release()
	checks["released_all_back"] = guard.attack_factor == 1.0 and gh.kind_factors.is_empty() and not ability.locked and not guard.is_in_group("rooted") and not bond.is_bound()
	var back_spell := gh.damage_typed(10.0, Health.DIRECT_SPELL, 2)
	checks["released_spell_full"] = absf(back_spell - spell_free) < 0.001
	structure.queue_free()
	guard.queue_free()
	twin.queue_free()
	return _verdict("guard_factors", checks)


## Farther than the leash from the attach point: a move order to 20 m from the building; closer, none; an
## order that already goes near the building stays (state.d:15366-15376).
func _leash() -> Dictionary:
	var checks := {}
	var structure := _structure(Vector3.ZERO)
	var near := _unit(Vector3(30.0, 0.0, 0.0), 1)
	var far := _unit(Vector3(0.0, 0.0, 70.0), 1)
	var busy := _unit(Vector3(80.0, 0.0, 0.0), 1)
	await _frames(3)
	var post := _post(structure)
	checks["attach_height"] = is_equal_approx(post.attach_height, 15.0) and post.attach_point().is_equal_approx(structure.global_position + Vector3(0.0, 15.0, 0.0))
	for unit in [near, far, busy]:
		GuardianBond.of(unit).bind(post)
	var busy_orders := busy.get_node("Orders")
	busy_orders.give(busy_orders.Command.MOVE, null, Vector3(40.0, 0.0, 0.0), Vector2.ZERO, 0.0)
	await _frames(3)
	var far_orders := far.get_node("Orders")
	var gap := Vector2(far_orders.point.x, far_orders.point.z).length()
	checks["far_gets_order"] = far_orders.command == far_orders.Command.MOVE and absf(gap - RULES.guardian_return_distance) < 1.5
	checks["near_no_order"] = near.get_node("Orders").command == near.get_node("Orders").Command.NONE
	checks["busy_order_kept"] = busy_orders.point.is_equal_approx(Vector3(40.0, 0.0, 0.0))
	checks["leash_numbers"] = is_equal_approx(RULES.guardian_leash, 50.0) and is_equal_approx(RULES.guardian_return_distance, 20.0)
	checks["still_bound"] = GuardianBond.of(far).is_bound()
	await _frames(1200)
	checks["comes_back"] = Vector2(far.global_position.x, far.global_position.z).length() < RULES.guardian_leash
	structure.queue_free()
	for unit in [near, far, busy]:
		unit.queue_free()
	return _verdict("guard_leash", checks)


## Dies, changes side, is taken by a doctor, the building falls (health 0 or freed) or the altar is destroyed: the
## bond ends, `post_path` empties, the post forgets it and the building takes hits again.
func _release() -> Dictionary:
	var checks := {}
	var structure := _structure(Vector3.ZERO)
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = 1
	altar.position = Vector3(300.0, 0.0, 0.0)
	_root.add_child(altar)
	var cases := {
		"dies": _unit(Vector3(10.0, 0.0, 10.0), 1),
		"changes_side": _unit(Vector3(12.0, 0.0, 10.0), 1),
		"taken": _unit(Vector3(14.0, 0.0, 10.0), 1),
		"building_dead": _unit(Vector3(16.0, 0.0, 10.0), 1),
		"altar_destroyed": _unit(Vector3(300.0, 0.0, 10.0), 1),
	}
	await _frames(3)
	var post := _post(structure)
	var altar_post := altar.get_node("GuardPost") as GuardPost
	checks["altar_post"] = is_equal_approx(altar_post.attach_height, 2.5) and altar_post.owner_slot() == 1 and altar_post.is_open()
	for key in cases:
		var bond := GuardianBond.of(cases[key])
		var ok := bond.bind(altar_post if key == "altar_destroyed" else post)
		checks["%s_bound" % key] = ok and not bond.post_path.is_empty()
	cases["dies"].get_node("Health").damage(99999.0, 2)
	cases["changes_side"].owner_slot = 2
	cases["taken"].mode = UnitBody.Mode.HELD
	altar.state = Altar.State.DESTROYED
	await _frames(3)
	for key in ["dies", "changes_side", "taken", "altar_destroyed"]:
		var bond := GuardianBond.of(cases[key])
		checks["%s_released" % key] = not bond.is_bound() and not cases[key].is_in_group("rooted") and bond.post == null
	checks["post_forgets"] = post.guard_count() == 1 and altar_post.guard_count() == 0
	checks["altar_closed"] = not altar_post.is_open()
	var health := structure.get_node("Health") as Health
	health.current = health.maximum
	health.damage(100.0, 2)
	checks["last_guard_still_covers"] = is_equal_approx(health.current, health.maximum)
	structure.queue_free()
	await _frames(3)
	var last := GuardianBond.of(cases["building_dead"])
	checks["building_gone_released"] = not last.is_bound() and last.post == null and not cases["building_dead"].is_in_group("rooted")
	for key in cases:
		if is_instance_valid(cases[key]):
			cases[key].queue_free()
	altar.queue_free()
	return _verdict("guard_release", checks)


## Arm: an own building within 50; target: a free own creature within 40; finish: tied to the post closest to
## the CREATURE, whatever the distance.
func _action() -> Dictionary:
	var checks := {}
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	wizard.global_position = Vector3(500.0, 0.0, 0.0)
	var caster := wizard.get_node("Caster")
	var action: GuardianAction = caster.action_for("ndrg")
	var spell: SpellType = caster.get("spellbook").structure_by_tag("ndrg")
	checks["found"] = action is GuardianAction and action.pick == SpellAction.Pick.OWN_UNIT and action.prompt == "Elegí una criatura propia"
	checks["no_warnings"] = action != null and action._get_configuration_warnings().is_empty()
	checks["armed_in_tab"] = caster.structure_status(int(caster.get("spellbook").structure_index_of("ndrg"))) == GuardianAction.FAR_FROM_BUILDING
	await _frames(2)
	checks["far_from_building"] = action.arm_status(wizard, spell) == "Lejos de un edificio propio"
	var near_post := _structure(Vector3(500.0, 0.0, 49.0))
	var far_post := _structure(Vector3(500.0, 0.0, -300.0))
	var enemy_post := _structure(Vector3(500.0, 0.0, 5.0), 2)
	await _frames(2)
	checks["arm_within_50"] = action.arm_status(wizard, spell).is_empty()
	enemy_post.queue_free()
	near_post.global_position = Vector3(500.0, 0.0, 51.0)
	checks["arm_just_over_50"] = action.arm_status(wizard, spell) == GuardianAction.FAR_FROM_BUILDING
	near_post.global_position = Vector3(500.0, 0.0, 49.0)
	var mine := _unit(Vector3(500.0, 0.0, -30.0), 1)
	var other := _unit(Vector3(500.0, 0.0, 20.0), 2)
	var distant := _unit(Vector3(500.0, 0.0, -41.0), 1)
	await _frames(2)
	checks["picks_own_unit"] = action.check(wizard, spell, mine.global_position, mine, "").status.is_empty()
	checks["enemy_invalid"] = action.check(wizard, spell, other.global_position, other, "").status == SpellAction.BAD_TARGET
	checks["wizard_invalid"] = action.check(wizard, spell, wizard.global_position, wizard, "").status == SpellAction.BAD_TARGET
	checks["nothing_invalid"] = action.check(wizard, spell, Vector3.ZERO, null, "").status == SpellAction.BAD_TARGET
	checks["over_40_out_of_range"] = action.check(wizard, spell, distant.global_position, distant, "").status == SpellAction.OUT_OF_RANGE
	checks["no_mana"] = action.check(wizard, spell, mine.global_position, mine, SpellAction.NO_MANA).status == SpellAction.NO_MANA
	checks["cooling_wins"] = action.check(wizard, spell, mine.global_position, mine, SpellAction.COOLING).status == SpellAction.COOLING
	checks["structure_invalid"] = action.check(wizard, spell, near_post.global_position, near_post, "").status == SpellAction.BAD_TARGET
	## Finish: the creature stands 300 m from the near post and 20 m from the far one, so it is tied to the far one.
	mine.global_position = Vector3(500.0, 0.0, -280.0)
	var aim := action.check(wizard, spell, mine.global_position, mine, "")
	action.begin(wizard, spell, aim)
	checks["finish_binds_closest_to_creature"] = action.finish(wizard, spell, mine).is_empty() and GuardianBond.of(mine).post == _post(far_post)
	checks["already_guardian_invalid"] = action.check(wizard, spell, mine.global_position, mine, "").status == SpellAction.BAD_TARGET
	var dead := _unit(Vector3(500.0, 0.0, -20.0), 1)
	await _frames(2)
	action.begin(wizard, spell, action.check(wizard, spell, dead.global_position, dead, ""))
	dead.get_node("Health").damage(99999.0, 2)
	checks["target_died_midway"] = action.finish(wizard, spell, null) == SpellAction.BAD_TARGET and action.finish(wizard, spell, dead) == SpellAction.BAD_TARGET
	var rooted := _unit(Vector3(500.0, 0.0, -25.0), 1)
	rooted.add_to_group("rooted")
	checks["rooted_invalid"] = not GuardianAction.can_guard(1, rooted)
	var bare := _unit(Vector3(500.0, 0.0, -22.0), 1)
	bare.get_node("GuardianBond").free()
	checks["no_bond_invalid"] = not GuardianAction.can_guard(1, bare)
	var held := _unit(Vector3(500.0, 0.0, -23.0), 1)
	held.mode = UnitBody.Mode.HELD
	checks["held_invalid"] = not GuardianAction.can_guard(1, held)
	var rules_less := GuardianAction.new()
	checks["rules_warns"] = rules_less._get_configuration_warnings().size() == 3
	rules_less.free()
	checks["other_slot_invalid"] = not GuardianAction.can_guard(2, mine) and not GuardianAction.can_guard(0, mine)
	for node in [wizard, near_post, far_post, mine, other, distant, dead, rooted, bare, held]:
		if is_instance_valid(node):
			node.queue_free()
	return _verdict("guard_action", checks)


## Binding takes the creature out of the selection and its groups; it can be picked again; the
## double click groups guardians of the same building apart from free creatures of the same type.
func _selection() -> Dictionary:
	var checks := {}
	var selection := SELECTION.new()
	_root.add_child(selection)
	var structure := _structure(Vector3.ZERO)
	var other_structure := _structure(Vector3(200.0, 0.0, 0.0))
	var a := _unit(Vector3(10.0, 0.0, 10.0), 1)
	var b := _unit(Vector3(12.0, 0.0, 10.0), 1)
	var c := _unit(Vector3(14.0, 0.0, 10.0), 1)
	var d := _unit(Vector3(16.0, 0.0, 10.0), 1)
	await _frames(3)
	selection._replace([a, b])
	selection.define_group(1)
	checks["selected"] = selection.size() == 2
	GuardianBond.of(a).bind(_post(structure))
	checks["dropped_from_selection"] = selection.size() == 1 and not selection.units().has(a)
	checks["dropped_from_groups"] = not (selection._groups[1] as Array).has(a) and (selection._groups[1] as Array).has(b)
	checks["still_selectable"] = selection.can_select(a)
	GuardianBond.of(b).bind(_post(structure))
	GuardianBond.of(c).bind(_post(other_structure))
	var of_a := selection._same_type_near(a)
	checks["guardian_double_click_same_building"] = of_a.has(a) and of_a.has(b) and not of_a.has(c) and not of_a.has(d)
	var of_d := selection._same_type_near(d)
	checks["free_double_click_skips_guardians"] = of_d == [d]
	selection.queue_free()
	structure.queue_free()
	other_structure.queue_free()
	for unit in [a, b, c, d]:
		unit.queue_free()
	return _verdict("guard_selection", checks)


func _structure(at: Vector3, slot := 1) -> Node3D:
	var structure := STRUCTURE_SCENE.instantiate() as Node3D
	structure.set("owner_slot", slot)
	structure.set("spell_tag", "htlm")
	structure.position = at
	_root.add_child(structure)
	return structure


func _post(host: Node) -> GuardPost:
	return host.get_node("GuardPost") as GuardPost


func _unit(at: Vector3, slot: int, tag := TAG) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.creature_tag = tag
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("guardian_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
