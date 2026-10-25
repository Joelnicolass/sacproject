extends "res://debug/suite/zone_case_base.gd"

## RFC-061j cases of rules_suite: Meanstalks through ZoneAction, GroundZone, Stalk, StalkHunt and StalkGrip: the numbers of the curve and the
## band, the ring of roots, how the stalks grow with the cast, who they catch and who they leave alone, the hold and the throw, the duration,
## a cut cast and what the AI makes of the spell. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.

const TAG := "rter"


func run(host: Node3D) -> Dictionary:
	begin(host, "StalkCases")
	var out := {}
	out["stalk_rules"] = _rules()
	out["stalk_scenes"] = await _scenes()
	out["stalk_catch"] = await _catch()
	out["stalk_duration"] = await _duration()
	out["stalk_cut"] = await _cut()
	out["stalk_ai"] = await _ai()
	finish()
	return out


func _rules() -> Dictionary:
	var checks := {}
	var tall := StalkRules.curve(Vector3.ZERO, Vector3(0.0, 60.0, 0.0), Vector3.ONE)
	checks["curve_ends"] = tall[0] == Vector3.ZERO and tall[7].is_equal_approx(Vector3(0.0, 60.0, 0.0)) and tall[3].is_equal_approx(tall[4])
	checks["tall_stalk_is_straight"] = tall[3].is_equal_approx(Vector3(0.0, 30.0, 0.0))
	var short := StalkRules.curve(Vector3.ZERO, Vector3(0.0, 30.0, 0.0), Vector3.ONE)
	var bulge := 0.5 * (sqrt(675.0) + sqrt(sqrt(675.0)))
	checks["short_stalk_bulges"] = absf((short[3] - Vector3(0.0, 15.0, 0.0)).length() - bulge) < 1e-3
	checks["radius"] = StalkRules.radius(0.0) == 2.0 and absf(StalkRules.radius(0.5) - 1.8) < 1e-5 and StalkRules.radius(1.0) == 0.0
	var base := Vector3.ZERO
	checks["band_edges"] = StalkRules.in_pick_band(base, Vector3(10.0, 0.0, 0.0)) and StalkRules.in_pick_band(base, Vector3(0.0, 0.0, 45.0))
	checks["band_outside"] = not StalkRules.in_pick_band(base, Vector3(9.9, 0.0, 0.0)) and not StalkRules.in_pick_band(base, Vector3(45.1, 0.0, 0.0))
	checks["band_height_counts_half"] = StalkRules.in_pick_band(base, Vector3(40.0, 20.0, 0.0)) and not StalkRules.in_pick_band(base, Vector3(40.0, 60.0, 0.0))
	var tip := Vector3(0.0, 60.0, 0.0)
	var velocity := Vector3.ZERO
	var goal := Vector3(70.0, 20.0, 0.0)
	var fastest := 0.0
	for _i in 1800:
		var step := StalkRules.step_tip(tip, velocity, goal, 30.0, 3.0)
		tip = step[0]
		velocity = step[1]
		fastest = maxf(fastest, velocity.length())
	checks["tip_speed_capped"] = fastest <= 30.0 + 1e-3 and fastest > 20.0
	checks["tip_arrives"] = tip.distance_to(goal) < 1.0
	var wander := StalkRules.wander_point(base, PI / 4.0, 0.0, 30.0, 60.0)
	checks["wander_cone"] = absf(wander.z - 30.0 * sin(PI / 4.0)) < 1e-4 and absf(wander.y - 60.0 * cos(PI / 4.0)) < 1e-4
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var click := Vector3(100.0, 0.0, -50.0)
	var ring_ok := true
	for _try in 50:
		var roots := ZoneRules.ring_points(rng, click, 4, 9.0, 21.6, deg_to_rad(22.5))
		ring_ok = ring_ok and roots.size() == 4
		for i in roots.size():
			var offset := roots[i] - click
			var angle := fposmod(atan2(offset.x, offset.z), TAU)
			var middle := PI / 4.0 + PI / 2.0 * i
			ring_ok = ring_ok and offset.length() >= 9.0 - 1e-3 and offset.length() <= 21.6 + 1e-3 and absf(angle - middle) <= deg_to_rad(22.5) + 1e-4
	checks["ring_of_roots"] = ring_ok
	return _verdict("stalk_rules", checks)


func _scenes() -> Dictionary:
	var checks := {}
	var spell := GameData.spell(TAG)
	checks["has_action"] = spell != null and spell.action != null
	var action := spell.action.instantiate() if spell and spell.action else null
	if action is ZoneAction:
		(action as ZoneAction).tag = TAG
		checks["kind_registered"] = _spawner.zones.has((action as ZoneAction).kind)
		checks["no_warnings"] = (action as ZoneAction)._get_configuration_warnings().is_empty()
		checks["ring_of_four"] = (action as ZoneAction).ring_count == 4
		checks["ground_pick"] = (action as ZoneAction).pick == SpellAction.Pick.GROUND
	if action != null:
		action.free()
	var scene := _spawner.zones["Meanstalks"] as PackedScene
	checks["zone_loads"] = scene.can_instantiate()
	var zone := scene.instantiate()
	var stalks := 0
	for child in zone.get_children():
		stalks += 1 if child is Stalk else 0
	checks["four_stalks"] = stalks == 4
	zone.free()
	checks["numbers"] = spell.damage == 500 and spell.duration_s == 60.0 and spell.effect_range_m == 60.0 and spell.speed_m_s == 30.0 and spell.acceleration_m_s2 == 3.0
	var book := GameData.book("persephone", 9)["spells"] as Array
	checks["in_persephones_book"] = book.any(func(type: SpellType) -> bool: return type.tag == TAG)
	checks["not_before_level_8"] = not (GameData.book("persephone", 7)["spells"] as Array).any(func(type: SpellType) -> bool: return type.tag == TAG)
	checks["ai_heal"] = AiSpellEval.rating_fn(spell) == AiSpellEval.FN_HEAL
	return _verdict("stalk_scenes", checks)


## One root has a Druid in its band: it grows with the cast, catches the Druid (500 of damage), hangs it from its tip, throws it, and never
## catches it twice; a body too close and one out of reach are left alone; an ally is caught too.
func _catch() -> Dictionary:
	var checks := {}
	var spell := GameData.spell(TAG)
	var wizard := _wizard(1, Vector3(-120.0, 0.0, 120.0), "persephone", 8)
	var prey := _tough(Vector3(45.0, 0.0, 0.0), 3)
	var too_close := _tough(Vector3(35.0, 0.0, 0.0), 3)
	var ally := _tough(Vector3(0.0, 0.0, -45.0), 2)
	await _frames(3)
	var roots := PackedVector3Array([Vector3(30.0, 0.0, 0.0), Vector3(0.0, 0.0, 30.0), Vector3(-30.0, 0.0, 0.0), Vector3(0.0, 0.0, -30.0)])
	var zone := _zone("Meanstalks", roots, wizard, 60, 0)
	var stalks: Array[Stalk] = []
	for child in zone.get_children():
		if child is Stalk:
			stalks.append(child)
	var holds := [0, 0, 0, 0]
	for i in stalks.size():
		stalks[i].mode_changed.connect(func(mode: int) -> void: holds[i] += 1 if mode == Stalk.Mode.HOLDING else 0)
	await _frames(30)
	checks["grows_with_the_cast"] = absf(stalks[0].growth - 30.0 / 180.0) < 0.03
	var hp_prey := (prey.get_node("Health") as Health).current
	var hp_close := (too_close.get_node("Health") as Health).current
	var resist := (prey.get_node("Health") as Health).resistance(Health.DIRECT_SPELL)
	await _frames(30)
	zone.release()
	var full_at := -1
	var hanging := true
	var held_ticks := 0
	var thrown_velocity := Vector3.ZERO
	var was_holding := false
	var after_hit := 0.0
	for tick in 1500:
		await _frames(1)
		if full_at < 0 and stalks[0].growth >= 1.0:
			full_at = tick + 60
		var holding := stalks[0].mode == Stalk.Mode.HOLDING and stalks[0].grip.holds()
		if holding:
			held_ticks += 1
			## The body moves with the tip's speed after it is put there (as in the original), so it leads the tip by one tick of that speed;
			## the tick of the catch itself the grip has not run yet.
			var gap := BodyNudge.center(prey).distance_to(stalks[0].tip)
			hanging = hanging and (held_ticks == 1 or gap <= BodyNudge.tumbling_of(prey).velocity.length() / MatchClock.TICKS_PER_SECOND_F + 0.3)
			if after_hit == 0.0:
				after_hit = hp_prey - (prey.get_node("Health") as Health).current
		elif was_holding and thrown_velocity == Vector3.ZERO and BodyNudge.tumbling_of(prey).is_on():
			thrown_velocity = BodyNudge.tumbling_of(prey).velocity
		was_holding = holding
	checks["full_growth_at_180"] = absi(full_at - 180) <= 2
	checks["first_stalk_holds_its_prey"] = held_ticks > 60
	checks["hit_500"] = absf(after_hit - 500.0 * resist) <= 500.0 * resist * TOLERANCE + 0.5
	checks["hangs_from_the_tip"] = hanging
	checks["thrown_with_the_tip_speed"] = thrown_velocity.y > 0.0 and thrown_velocity.length() >= 5.0
	checks["ally_caught_too"] = holds[3] == 1
	checks["too_close_ignored"] = (too_close.get_node("Health") as Health).current >= hp_close
	checks["each_body_once"] = holds[0] == 1 and holds[1] == 0 and holds[2] == 0 and holds[3] == 1
	checks["numbers_used"] = spell.damage == 500
	zone.queue_free()
	for node: Node in [wizard, prey, too_close, ally]:
		node.queue_free()
	await _frames(2)
	return _verdict("stalk_catch", checks)


## The zone acts for the spell's duration, counted from the end of the cast; then it ends and the stalks sink in `end_s`.
func _duration() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-120.0, 0.0, 120.0), "persephone", 8)
	await _frames(3)
	var roots := PackedVector3Array([Vector3(30.0, 0.0, 0.0), Vector3(0.0, 0.0, 30.0), Vector3(-30.0, 0.0, 0.0), Vector3(0.0, 0.0, -30.0)])
	var zone := _zone("Meanstalks", roots, wizard, 30, 0)
	zone.spell = zone.spell.duplicate()
	zone.spell.duration_s = 5.0
	await _frames(30)
	zone.release()
	var active := 0
	while zone.phase != GroundZone.Phase.ENDING and active < 1000:
		await _frames(1)
		active += 1
	checks["acts_for_the_duration"] = absi(active - 300) <= 2
	var sinking := 0
	while is_instance_valid(zone) and not zone.is_queued_for_deletion() and sinking < 400:
		await _frames(1)
		sinking += 1
	checks["gone_after_end_s"] = absi(sinking - 192) <= 3
	checks["data_duration"] = GameData.spell(TAG).duration_s == 60.0
	wizard.queue_free()
	await _frames(2)
	return _verdict("stalk_duration", checks)


## A cast that is cut: nobody is hurt, the stalks sink and the zone goes.
func _cut() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-120.0, 0.0, 120.0), "persephone", 8)
	var prey := _tough(Vector3(45.0, 0.0, 0.0), 3)
	await _frames(3)
	var roots := PackedVector3Array([Vector3(30.0, 0.0, 0.0), Vector3(0.0, 0.0, 30.0), Vector3(-30.0, 0.0, 0.0), Vector3(0.0, 0.0, -30.0)])
	var zone := _zone("Meanstalks", roots, wizard, 200, 0)
	var hp := (prey.get_node("Health") as Health).current
	await _frames(100)
	zone.cancel()
	await _frames(300)
	checks["zone_gone"] = _zones().is_empty()
	checks["nobody_hurt"] = (prey.get_node("Health") as Health).current == hp
	checks["nobody_thrown"] = not BodyNudge.tumbling_of(prey).is_on()
	for node: Node in [wizard, prey]:
		node.queue_free()
	await _frames(2)
	return _verdict("stalk_cut", checks)


func _ai() -> Dictionary:
	var checks := {}
	var perception := AiPerception.new()
	perception.name = "StalkCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "persephone", 8)
	var foe := _tough(Vector3(-380.0, 0.0, -400.0), 3)
	await _frames(3)
	var stance := AiStance.new()
	stance.recs[0].manaliths = 1
	var groups := AiGroups.new()
	groups.perception = perception
	groups.profile = perception.profile
	_root.add_child(groups)
	var eval := AiSpellEval.new(perception, stance, groups, perception.profile)
	var track := perception.add_node(wizard, &"event")
	var foe_track := perception.add_node(foe, &"event")
	groups.rebuild()
	var spell := GameData.spell(TAG)
	checks["tracked"] = track != null and foe_track != null
	if checks["tracked"]:
		var rated := eval.rate(track, spell, foe_track, 0.0)
		checks["rates_finite"] = is_finite(rated) and rated >= 0.0
	stance.free()
	for node: Node in [perception, groups, wizard, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("stalk_ai", checks)
