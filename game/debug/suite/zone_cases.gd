extends "res://debug/suite/zone_case_base.gd"

## RFC-061f cases of rules_suite: the ground zones (Explosion, Frozen Ground, Demonic Rift) through ZoneAction, GroundZone, ZonePulse and
## its classes, and Healing Aura through WardAction, Ward and BodyAura: the numbers of each spell, when it acts, who it reaches and who it
## leaves alone, and what the AI makes of them. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.

const SPELLS: Array[String] = ["pxef", "zorf", "tfir", "ruah"]


func run(host: Node3D) -> Dictionary:
	begin(host, "ZoneCases")
	var out := {}
	out["zone_rules"] = _rules()
	out["zone_scenes"] = await _scenes()
	out["zone_explosion_blast"] = await _explosion_blast()
	out["zone_explosion_cast"] = await _explosion_cast()
	out["zone_frozen_freeze"] = await _frozen_freeze()
	out["zone_frozen_shatter"] = await _frozen_shatter()
	out["zone_ai"] = await _ai()
	finish()
	return out


## The plain numbers: how hard a blast throws, which point a body answers to, how the ice grows and where each ring reaches.
func _rules() -> Dictionary:
	var checks := {}
	checks["throw_at_0"] = ZoneRules.throw_strength(0.0, 10.0) == 20.0
	checks["throw_at_5"] = absf(ZoneRules.throw_strength(5.0, 10.0) - 13.75) < 1e-4
	checks["throw_at_10"] = absf(ZoneRules.throw_strength(10.0, 10.0) - 5.0) < 1e-4
	var points := PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0), Vector3(30.0, 0.0, 0.0)])
	checks["first_wins_in_range"] = ZoneRules.nearest_blast(points, Vector3(6.0, 0.0, 0.0), 10.0) == 0
	checks["else_closest"] = ZoneRules.nearest_blast(points, Vector3(14.0, 0.0, 0.0), 10.0) == 1
	checks["none_out_of_range"] = ZoneRules.nearest_blast(points, Vector3(20.0, 0.0, 0.0), 5.0) == -1
	var thrown := ZoneRules.throw_velocity(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, 10.0)
	checks["throw_goes_up_and_away"] = thrown.y > 0.0 and thrown.x > 0.0 and absf(thrown.length() - 13.75) < 0.01
	checks["ice_starts_fast"] = ZoneRules.grown_radius(15.0, 0, 30) == 0.0 and ZoneRules.grown_radius(15.0, 15, 30) > 15.0 * 0.85
	checks["ice_whole"] = ZoneRules.grown_radius(15.0, 30, 30) == 15.0 and ZoneRules.grown_radius(15.0, 5, 0) == 15.0
	checks["ring_steps"] = absf(ZoneRules.ring_radius(1, 6, 15.0) - 2.5) < 1e-4 and ZoneRules.ring_radius(6, 6, 15.0) == 15.0
	var box := AABB(Vector3(2.0, 0.0, 0.0), Vector3(1.0, 2.0, 1.0))
	checks["flat_gap"] = ZoneRules.flat_gap(box, Vector3(0.0, 9.0, 0.5)) == 2.0 and ZoneRules.flat_gap(box, Vector3(2.5, 0.0, 0.5)) == 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var inside := true
	for _i in 200:
		inside = inside and ZoneRules.disk_point(rng, 20.0).length() <= 20.0
	checks["disk_inside"] = inside
	return _verdict("zone_rules", checks)


## Each spell has its action and its zone scene, the zone scene is registered in the spawner, and nothing warns.
func _scenes() -> Dictionary:
	var checks := {}
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		checks[tag + "_has_action"] = spell != null and spell.action != null
		var action := spell.action.instantiate() if spell and spell.action else null
		if action is ZoneAction:
			(action as ZoneAction).tag = tag
			checks[tag + "_kind_registered"] = _spawner.zones.has((action as ZoneAction).kind)
			checks[tag + "_no_warnings"] = (action as ZoneAction)._get_configuration_warnings().is_empty()
			checks[tag + "_zone_loads"] = (_spawner.zones[(action as ZoneAction).kind] as PackedScene).can_instantiate()
		if action != null:
			action.free()
	for tag in ["pxef", "zorf", "tfir"]:
		var made := GameData.spell(tag).action.instantiate() as SpellAction
		checks[tag + "_ground_pick"] = made.pick == SpellAction.Pick.GROUND
		checks[tag + "_ai_area"] = GameData.spell(tag).ai_use == SpellType.AiUse.HIT_AREA
		made.free()
	await _frames(1)
	return _verdict("zone_scenes", checks)


## The blast: 600 falling off to 0 in 10 m, a fire on every body it reaches, the throw of everything within 30 m of the first point,
## and the first point wins. The numbers come straight from the pulse (the timing is the next case).
func _explosion_blast() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("pxef")
	var wizard := _wizard(1, Vector3(-60.0, 0.0, 0.0), "pyro", 6)
	var inside := _tough(Vector3(0.0, 0.0, 0.0), 3)
	var five := _tough(Vector3(5.0, 0.0, 0.0), 3)
	var eleven := _tough(Vector3(11.5, 0.0, 0.0), 3)
	var far := _tough(Vector3(33.0, 0.0, 0.0), 3)
	var ally := _tough(Vector3(0.0, 0.0, 4.0), 1)
	await _frames(3)
	var points := PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -40.0), Vector3(40.0, 0.0, 40.0), Vector3(-40.0, 0.0, 40.0), Vector3(0.0, 0.0, 60.0)])
	var zone := _zone("Explosion", points, wizard, 0, 0)
	await _frames(2)
	checks["zone_in_group"] = zone != null and zone.is_in_group(GroundZone.GROUP)
	checks["starts_casting"] = zone.phase == GroundZone.Phase.CASTING
	var hp := {}
	for body in [inside, five, eleven, far, ally]:
		hp[body] = (body.get_node("Health") as Health).current
	var blast := zone.get_node("Blast") as ZoneBlast
	blast._fire(0)
	var resist := (inside.get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var took_inside := float(hp[inside]) - (inside.get_node("Health") as Health).current
	checks["inside_600"] = absf(took_inside - 600.0 * resist) <= 600.0 * resist * TOLERANCE + 0.5
	var box_gap := ZoneRules.flat_gap(BodyNudge.box(five), points[0])
	var took_five := float(hp[five]) - (five.get_node("Health") as Health).current
	var want_five := 600.0 * (1.0 - SplashDamage.box_distance(five, points[0]) / 10.0) * resist
	checks["five_falls_off"] = box_gap > 0.0 and absf(took_five - want_five) <= want_five * TOLERANCE + 0.5 and took_five < took_inside
	checks["eleven_untouched_by_damage"] = hp[eleven] == (eleven.get_node("Health") as Health).current
	checks["far_untouched"] = hp[far] == (far.get_node("Health") as Health).current
	checks["fire_on_reached"] = inside.get_node_or_null("Burning") != null and five.get_node_or_null("Burning") != null
	checks["no_fire_out_of_blast"] = eleven.get_node_or_null("Burning") == null and far.get_node_or_null("Burning") == null
	var t_inside := BodyNudge.tumbling_of(inside)
	var t_five := BodyNudge.tumbling_of(five)
	var t_eleven := BodyNudge.tumbling_of(eleven)
	checks["inside_thrown_at_20"] = t_inside.is_on() and absf(t_inside.velocity.length() - 20.0) <= 0.2
	checks["five_thrown_at_13_75"] = t_five.is_on() and absf(t_five.velocity.length() - 13.75) <= 0.14 and t_five.velocity.y > 0.0 and t_five.velocity.x > 0.0
	checks["eleven_not_thrown"] = not t_eleven.is_on()
	checks["far_not_thrown"] = not BodyNudge.tumbling_of(far).is_on()
	checks["ally_thrown_too"] = BodyNudge.tumbling_of(ally).is_on()
	zone.queue_free()
	for node: Node in [wizard, inside, five, eleven, far, ally]:
		node.queue_free()
	await _frames(2)
	checks["spell_numbers"] = spell.damage == 600 and spell.damage_range_m == 10.0 and spell.effect_range_m == 20.0
	return _verdict("zone_explosion_blast", checks)


## The cast through the book: five points (the click and four within 20 m), the blast at 228 ticks from the start of the cast (±1), mana and
## cooldown taken, and a cast that is cut does nothing and leaves no zone.
func _explosion_cast() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("pxef")
	var wizard := _wizard(1, Vector3(-30.0, 0.0, 0.0), "pyro", 6)
	var foe := _tough(Vector3(20.0, 0.0, 0.0), 3)
	await _frames(3)
	var caster := Caster.of(wizard)
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	var index := caster.spellbook.index_of("pxef")
	checks["in_book"] = index >= 0
	var action := caster.action_for("pxef")
	checks["action"] = action is ZoneAction and action.pick == SpellAction.Pick.GROUND
	checks["arm_ok"] = caster.arm_status(index).is_empty()
	var click := Vector3(20.0, 0.0, 0.0)
	caster.request_cast("pxef", click, null)
	checks["casting"] = caster.is_casting()
	var zones := _zones()
	checks["one_zone"] = zones.size() == 1
	var zone: GroundZone = zones[0] if not zones.is_empty() else null
	if zone != null:
		checks["five_points"] = zone.points.size() == 5 and zone.points[0].is_equal_approx(click)
		var within := true
		for i in range(1, zone.points.size()):
			within = within and zone.points[i].distance_to(click) <= spell.effect_range_m + 0.01
		checks["four_within_20"] = within
		checks["cast_ticks"] = zone.cast_ticks > 0
		var before := (foe.get_node("Health") as Health).current
		var ticks := 0
		while zone.phase != GroundZone.Phase.ACTIVE and ticks < 400:
			await _frames(1)
			ticks += 1
		checks["blast_at_228"] = absi(ticks - 228) <= 1
		checks["foe_hurt"] = (foe.get_node("Health") as Health).current < before
		checks["foe_burns_or_thrown"] = BodyNudge.tumbling_of(foe).is_on() or foe.get_node_or_null("Burning") != null
	checks["mana_spent"] = pool.current < 5000.0 - float(spell.mana_cost) * 0.9
	checks["cooling"] = caster.spellbook.cooldown(index) > 0.0
	await _frames(70)
	checks["zone_gone"] = _zones().is_empty()
	## A cut cast: the wizard dies in the middle of it.
	var wizard_2 := _wizard(1, Vector3(-30.0, 0.0, 30.0), "pyro", 6)
	var foe_2 := _tough(Vector3(20.0, 0.0, 30.0), 3)
	await _frames(3)
	var caster_2 := Caster.of(wizard_2)
	(wizard_2.get_node("ManaPool") as ManaPool).maximum = 10000.0
	(wizard_2.get_node("ManaPool") as ManaPool).current = 5000.0
	caster_2.request_cast("pxef", foe_2.global_position, null)
	await _frames(30)
	var cut_zone: GroundZone = _zones()[0] if not _zones().is_empty() else null
	checks["cut_zone_exists"] = cut_zone != null
	(wizard_2.get_node("Health") as Health).damage(99999.0, 3)
	var foe_hp := (foe_2.get_node("Health") as Health).current
	await _frames(300)
	checks["cut_cancelled"] = cut_zone == null or not is_instance_valid(cut_zone)
	checks["cut_no_damage"] = (foe_2.get_node("Health") as Health).current == foe_hp
	checks["cut_no_throw"] = not BodyNudge.tumbling_of(foe_2).is_on()
	checks["cut_no_zone_left"] = _zones().is_empty()
	for node: Node in [wizard, foe, wizard_2, foe_2]:
		node.queue_free()
	await _frames(2)
	return _verdict("zone_explosion_cast", checks)


## Frozen Ground, the freeze: the snowball lands 120 ticks after the cast ends, and while the ice grows (30 ticks) every enemy on the ground
## inside it freezes once; a flier, an ally, a body with Life Shield and one outside the radius are left alone.
func _frozen_freeze() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("zorf")
	var wizard := _wizard(1, Vector3(-40.0, 0.0, 0.0), "stratos", 6)
	var near := _unit("ycro", Vector3(10.0, 0.0, 0.0), 3)
	var rim := _unit("ycro", Vector3(0.0, 0.0, 14.7), 3)
	var out := _unit("ycro", Vector3(16.5, 0.0, 0.0), 3)
	var flier := _unit("tbsh", Vector3(0.0, 0.0, -6.0), 3)
	var ally := _unit("ycro", Vector3(-5.0, 0.0, 0.0), 2)
	var guarded := _unit("nmuh", Vector3(0.0, 0.0, 5.0), 3)
	await _frames(60)
	LifeShield.of(guarded).start(100000)
	await _frames(2)
	var zone := _zone("FrozenGround", PackedVector3Array([Vector3.ZERO]), wizard, 0, 120)
	checks["hold_is_the_spell_duration"] = zone.hold_is_spell_duration and zone.hold_ticks() == ceili(60.0 * spell.duration_s) and spell.duration_s == 30.0
	checks["casting"] = zone.phase == GroundZone.Phase.CASTING
	zone.release()
	checks["arming"] = zone.phase == GroundZone.Phase.ARMING
	var ticks := 0
	while zone.phase != GroundZone.Phase.ACTIVE and ticks < 400:
		await _frames(1)
		ticks += 1
	checks["lands_at_120"] = absi(ticks - 120) <= 1
	checks["nothing_frozen_before"] = not Frozen.is_frozen(near) and not Frozen.is_frozen(rim)
	zone.hold_is_spell_duration = false
	zone.hold_s = 1.0
	await _frames(15)
	checks["radius_grows"] = zone.grown_m(15.0) > 10.0 and zone.grown_m(15.0) < 15.0
	checks["near_frozen_in_15"] = Frozen.is_frozen(near)
	checks["rim_not_yet"] = not Frozen.is_frozen(rim)
	await _frames(16)
	checks["rim_frozen_by_30"] = Frozen.is_frozen(rim)
	checks["out_never"] = not Frozen.is_frozen(out)
	checks["flier_never"] = not Frozen.is_frozen(flier)
	checks["ally_never"] = not Frozen.is_frozen(ally) and not Frozen.is_frozen(wizard)
	checks["shielded_never"] = not Frozen.is_frozen(guarded)
	var zerf := GameData.spell("zerf")
	var lasts := (near.get_node("Afflictions/Frozen") as Frozen).lay_ticks(zerf)
	checks["freeze_numbers_are_freezes"] = absi(lasts - ceili(60.0 * 1000.0 / (near.get_node("Health") as Health).maximum * zerf.duration_s)) <= 1
	checks["uses_zerf"] = (zone.get_node("Freeze") as ZoneFreeze).freeze_spell == zerf
	zone.queue_free()
	for node: Node in [wizard, near, rim, out, flier, ally, guarded]:
		node.queue_free()
	await _frames(2)
	return _verdict("zone_frozen_freeze", checks)


## Frozen Ground, the break: after its time the ice goes in 6 steps of 5 ticks from the centre out, and each body on the ground takes 800 once,
## in the step its distance falls in; a body outside 15 m takes nothing.
func _frozen_shatter() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-40.0, 0.0, 0.0), "stratos", 6)
	var bodies := {
		"three": _tough(Vector3(3.0, 0.0, 0.0), 3),
		"eight": _tough(Vector3(0.0, 0.0, 8.0), 3),
		"fourteen": _tough(Vector3(-14.0, 0.0, 0.0), 3),
		"twenty": _tough(Vector3(0.0, 0.0, -20.0), 3),
	}
	await _frames(3)
	var zone := _zone("FrozenGround", PackedVector3Array([Vector3.ZERO]), wizard, 0, 0)
	zone.hold_is_spell_duration = false
	zone.hold_s = 0.05
	(zone.get_node("Freeze") as ZoneFreeze).set_physics_process(false)
	zone.release()
	var spell := GameData.spell("zorf")
	var resist := (bodies["three"].get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var start := {}
	var step_of := {}
	for key in bodies:
		start[key] = (bodies[key].get_node("Health") as Health).current
	while zone.phase != GroundZone.Phase.ENDING:
		await _frames(1)
	var ticks := 0
	while is_instance_valid(zone) and ticks < 60:
		await _frames(1)
		ticks += 1
		for key in bodies:
			if not step_of.has(key) and (bodies[key].get_node("Health") as Health).current < float(start[key]):
				step_of[key] = ticks
	for key in ["three", "eight", "fourteen"]:
		var took := float(start[key]) - (bodies[key].get_node("Health") as Health).current
		checks[key + "_took_800_once"] = absf(took - 800.0 * resist) <= 800.0 * resist * TOLERANCE + 0.5
	checks["three_in_step_2"] = absi(int(step_of.get("three", -99)) - 10) <= 1
	checks["eight_in_step_4"] = absi(int(step_of.get("eight", -99)) - 20) <= 1
	checks["fourteen_in_step_6"] = absi(int(step_of.get("fourteen", -99)) - 30) <= 1
	checks["twenty_untouched"] = (bodies["twenty"].get_node("Health") as Health).current == float(start["twenty"])
	checks["zone_freed"] = not is_instance_valid(zone) or zone.is_queued_for_deletion()
	checks["spell_numbers"] = spell.damage == 800 and spell.effect_range_m == 15.0
	for node: Node in bodies.values() + [wizard]:
		node.queue_free()
	await _frames(2)
	return _verdict("zone_frozen_shatter", checks)


## The AI rates the four with the evaluators their `ai_use` gives them (the three ground spells as area spells, Healing Aura as a heal on an area), the
## numbers are finite and nothing breaks.
func _ai() -> Dictionary:
	var checks := {}
	var perception: AiPerception = preload("res://debug/suite/ai_perception_rig.tscn").instantiate()
	perception.name = "ZoneCasesPerception"
	perception.play = AiPlay.normal()
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "pyro", 6)
	var foe := _tough(Vector3(-380.0, 0.0, -400.0), 3)
	var hurt := _tough(Vector3(-380.0, 0.0, -390.0), 1)
	await _frames(3)
	(hurt.get_node("Health") as Health).current = 1000.0
	var stance := AiStance.new()
	stance.recs[0].manaliths = 1
	var groups := AiGroups.new()
	groups.perception = perception
	_root.add_child(groups)
	var eval := AiSpellEval.new(perception, stance, groups, perception.play.tactics)
	var track := perception.add_node(wizard, &"event")
	var foe_track := perception.add_node(foe, &"event")
	var hurt_track := perception.add_node(hurt, &"event")
	groups.rebuild()
	checks["tracked"] = track != null and foe_track != null and hurt_track != null
	var wanted := {"pxef": AiSpellEval.FN_AREA, "zorf": AiSpellEval.FN_AREA, "tfir": AiSpellEval.FN_AREA, "ruah": AiSpellEval.FN_HEAL_AREA}
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		checks[tag + "_evaluator"] = AiSpellEval.rating_fn(spell) == wanted[tag]
		if checks["tracked"]:
			var rated := eval.rate(track, spell, hurt_track if tag == "ruah" else foe_track, 0.0)
			checks[tag + "_rates_finite"] = is_finite(rated) and rated >= 0.0
	stance.free()
	for node: Node in [perception, groups, wizard, foe, hurt]:
		node.queue_free()
	await _frames(2)
	return _verdict("zone_ai", checks)
