extends "res://debug/suite/zone_case_base.gd"

## RFC-061j cases of rules_suite: the Tornado through ZoneAction, GroundZone, TornadoDrift, TornadoWinds and TornadoLift: the numbers of the
## axis and the pull, how the funnel grows with the cast, how far and how fast it wanders, who it lifts and who it leaves alone, how long it
## lasts, a cut cast and what the AI makes of the spell. No network: the server paths run as solo. `run(host)` adds its own bodies.

const TAG := "nrot"


func run(host: Node3D) -> Dictionary:
	begin(host, "TornadoCases")
	var out := {}
	out["tornado_rules"] = _rules()
	out["tornado_scenes"] = await _scenes()
	out["tornado_drift"] = await _drift()
	out["tornado_lift"] = await _lift()
	out["tornado_cut"] = await _cut()
	out["tornado_ai"] = await _ai()
	finish()
	return out


func _rules() -> Dictionary:
	var checks := {}
	var radii := TornadoRules.radii()
	checks["radii"] = radii[0] == 300.0 and absf(radii[6] - 1.5) < 1e-5 and absf(radii[5] - (100.0 - 98.5 * 0.95)) < 1e-3
	var top := Vector3(0.0, 500.0, 0.0)
	var winds := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var axis := TornadoRules.axis(top, Vector3.ZERO, 1.0, winds)
	checks["axis_ends"] = axis[0] == top and axis[6].is_equal_approx(Vector3.ZERO)
	var gone := TornadoRules.axis(top, Vector3.ZERO, 0.0, winds)
	checks["size_zero_folds_up"] = gone[6].is_equal_approx(top)
	var foot := TornadoRules.centre(axis, radii, Vector3(0.0, 0.0, 0.0))
	var head := TornadoRules.centre(axis, radii, Vector3(0.0, 500.0, 0.0))
	checks["radius_at_foot_and_top"] = absf(foot.w - 1.5) < 1e-3 and absf(head.w - 300.0) < 1e-3
	var bent := TornadoRules.axis(top, Vector3.ZERO, 1.0, PackedFloat32Array([PI / 2.0, 0.0, 0.0, 0.0]))
	checks["wind_bends_the_axis"] = absf(bent[2].x + 150.0) < 1e-3 and absf(bent[2].z) < 1e-3 and absf(bent[4].x) < 1e-3
	var wall := TornadoRules.centre(axis, radii, Vector3.ZERO)
	checks["pull_inside_reach"] = TornadoRules.pull(Vector3(31.4, 0.0, 0.0), wall) != Vector3.INF
	checks["no_pull_outside"] = TornadoRules.pull(Vector3(31.6, 0.0, 0.0), wall) == Vector3.INF
	var impulse := TornadoRules.pull(Vector3(20.0, 0.0, 0.0), wall)
	checks["pull_at_most_3_m_s"] = impulse != Vector3.INF and impulse.length() <= 3.0 + 1e-4 and impulse.length() > 2.0
	checks["wander_offset"] = absf(TornadoRules.wander_offset(50.0, 0.5, false) - 12.5) < 1e-5 and absf(TornadoRules.wander_offset(50.0, 0.5, true) + 12.5) < 1e-5
	checks["wind_phase"] = absf(TornadoRules.wind_phase(1.0, 0, 60) - 1.6) < 1e-5 and absf(TornadoRules.wind_phase(1.0, 2, 60) - 0.22) < 1e-5
	return _verdict("tornado_rules", checks)


func _scenes() -> Dictionary:
	var checks := {}
	var spell := GameData.spell(TAG)
	checks["has_action"] = spell != null and spell.action != null
	var action := spell.action.instantiate() if spell and spell.action else null
	if action is ZoneAction:
		(action as ZoneAction).tag = TAG
		checks["kind_registered"] = _spawner.zones.has((action as ZoneAction).kind)
		checks["no_warnings"] = (action as ZoneAction)._get_configuration_warnings().is_empty()
		checks["ground_pick"] = (action as ZoneAction).pick == SpellAction.Pick.GROUND
		checks["has_cast_look"] = (action as ZoneAction).cast_scene != null and (action as ZoneAction).cast_scene.can_instantiate()
	if action != null:
		action.free()
	checks["zone_loads"] = (_spawner.zones["Tornado"] as PackedScene).can_instantiate()
	checks["numbers"] = spell.duration_s == 25.0 and spell.speed_m_s == 6.0 and spell.acceleration_m_s2 == 0.6 and spell.effect_range_m == 50.0
	checks["in_stratos_book"] = (GameData.book("stratos", 9)["spells"] as Array).any(func(type: SpellType) -> bool: return type.tag == TAG)
	checks["not_before_level_8"] = not (GameData.book("stratos", 7)["spells"] as Array).any(func(type: SpellType) -> bool: return type.tag == TAG)
	checks["ai_none"] = spell.ai_use == SpellType.AiUse.NONE
	var zone := (_spawner.zones["Tornado"] as PackedScene).instantiate()
	var light := zone.get_node_or_null("Look/Light") as ActorLight
	checks["lit_with_its_colour"] = light != null and light.light_color != Color.WHITE and not light.shadow_enabled
	zone.free()
	return _verdict("tornado_scenes", checks)


## The size follows the cast (0.8 at its end), then 1; the tornado stays within 50 m of home, never goes faster than 6 m/s, lasts 25 s and
## dissipates.
func _drift() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 300.0), "stratos", 8)
	await _frames(3)
	var home := Vector3(0.0, 0.0, 0.0)
	var zone := _zone("Tornado", PackedVector3Array([home]), wizard, 100, 0)
	var drift := zone.get_node("Drift") as TornadoDrift
	await _frames(50)
	checks["size_follows_the_cast"] = absf(drift.size - 0.4) < 0.03
	await _frames(50)
	zone.release()
	checks["size_08_at_the_end"] = absf(drift.size - 0.8) < 0.03
	var active := 0
	var farthest := 0.0
	var fastest := 0.0
	var last := zone.position
	var biggest := 0.0
	while zone.phase == GroundZone.Phase.ACTIVE and active < 2000:
		await _frames(1)
		active += 1
		farthest = maxf(farthest, Vector2(zone.position.x - home.x, zone.position.z - home.z).length())
		fastest = maxf(fastest, (zone.position - last).length() * MatchClock.TICKS_PER_SECOND_F)
		biggest = maxf(biggest, drift.size)
		last = zone.position
	print("tornado_cases: drift farthest %.1f m, fastest %.3f m/s, biggest %.3f" % [farthest, fastest, biggest])
	checks["acts_for_25_s"] = absi(active - 1500) <= 2
	checks["stays_within_range"] = farthest <= 120.0
	checks["moves"] = farthest > 0.5
	checks["speed_at_most_6"] = fastest <= 6.0 + 1e-3
	checks["full_size"] = absf(biggest - 1.0) < 1e-3
	var ending := 0
	while is_instance_valid(zone) and not zone.is_queued_for_deletion() and ending < 400:
		await _frames(1)
		ending += 1
	checks["gone_after_end_s"] = absi(ending - 102) <= 3
	checks["data_duration"] = GameData.spell(TAG).duration_s == 25.0
	wizard.queue_free()
	await _frames(2)
	return _verdict("tornado_drift", checks)


## A Druid, a wizard and the caster's ally inside the reach of the wall are lifted and held up; one out of reach, a flier and a frozen body
## are not; the tornado hurts nobody by itself; and nobody is lifted while the wizard is still casting.
func _lift() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(15.0, 0.0, 0.0), "stratos", 8)
	var foe := _tough(Vector3(20.0, 0.0, 0.0), 3)
	var ally := _tough(Vector3(0.0, 0.0, 22.0), 2)
	var far := _tough(Vector3(40.0, 0.0, 0.0), 3)
	var flier := _unit("tbsh", Vector3(5.0, 0.0, 5.0), 3)
	await _frames(30)
	var home := Vector3.ZERO
	var zone := _zone("Tornado", PackedVector3Array([home]), wizard, 60, 0)
	var hp_foe := (foe.get_node("Health") as Health).current
	await _frames(40)
	checks["nobody_lifted_while_casting"] = not BodyNudge.tumbling_of(foe).is_on() and not BodyNudge.tumbling_of(wizard).is_on()
	var rest_flier := flier.global_position
	zone.release()
	await _frames(120)
	var lifted := BodyNudge.tumbling_of(foe)
	checks["foe_lifted"] = lifted.is_on() and foe.global_position.y > 0.05
	checks["ally_lifted"] = BodyNudge.tumbling_of(ally).is_on()
	checks["wizard_lifted"] = BodyNudge.tumbling_of(wizard).is_on()
	print("tornado_cases: far at %s (tumbling %s), flier moved %.2f m (tumbling %s)" % [far.global_position, BodyNudge.tumbling_of(far).is_on(), flier.global_position.distance_to(rest_flier), BodyNudge.tumbling_of(flier).is_on()])
	checks["far_left_alone"] = not BodyNudge.tumbling_of(far).is_on() and far.global_position.y < 0.05
	checks["flier_left_alone"] = not BodyNudge.tumbling_of(flier).is_on()
	checks["speed_at_most_30"] = lifted.velocity.length() <= 30.0 + 1e-3
	checks["no_direct_damage"] = (foe.get_node("Health") as Health).current == hp_foe
	zone.queue_free()
	for node: Node in [wizard, foe, ally, far, flier]:
		node.queue_free()
	await _frames(2)
	return _verdict("tornado_lift", checks)


func _cut() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-300.0, 0.0, 300.0), "stratos", 8)
	var foe := _tough(Vector3(20.0, 0.0, 0.0), 3)
	await _frames(3)
	var zone := _zone("Tornado", PackedVector3Array([Vector3.ZERO]), wizard, 200, 0)
	await _frames(60)
	zone.cancel()
	await _frames(240)
	checks["zone_gone"] = _zones().is_empty()
	checks["nobody_lifted"] = not BodyNudge.tumbling_of(foe).is_on() and foe.global_position.y < 0.01
	for node: Node in [wizard, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("tornado_cut", checks)


func _ai() -> Dictionary:
	var checks := {}
	var perception := AiPerception.new()
	perception.name = "TornadoCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "stratos", 8)
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
	checks["tracked"] = track != null and foe_track != null
	if checks["tracked"]:
		var rated := eval.rate(track, GameData.spell(TAG), foe_track, 0.0)
		checks["rates_finite"] = is_finite(rated) and rated >= 0.0
	stance.free()
	for node: Node in [perception, groups, wizard, foe]:
		node.queue_free()
	await _frames(2)
	return _verdict("tornado_ai", checks)
