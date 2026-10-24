extends RefCounted

## RFC-061d cases of rules_suite: the spells that fetch souls. Soul Mole and Soul Wind send a SpellCarrier to a soul and back (the route, what
## it does to the bodies it passes, what happens to the soul, what a cancel or a lost soul does) and the three spells refuse what they must.
## Animate Dead is in animate_dead_cases.gd. No network: the server paths run as solo. Time is the physics tick, so a trip of 540 ticks
## runs in `--fixed-fps 600` quickly. `run(host)` adds its own world and removes it.

const WORLD := preload("res://debug/suite/soul_world.gd")
const SOUL_SPELLS := {"pmcd": "james", "dnws": "stratos", "deda": "charnel"}

var _w := WORLD.new()


func run(host: Node3D) -> Dictionary:
	_w.build(host, "SoulCases")
	var out := {}
	out["soul_path"] = _path()
	out["soul_scenes"] = _scenes()
	out["soul_mole"] = await _mole()
	out["soul_mole_corpse"] = await _mole_corpse()
	out["soul_wind"] = await _wind()
	out["soul_cancel"] = await _cancel()
	out["soul_refusals"] = await _refusals()
	out["soul_ai"] = _ai()
	_w.clear()
	return out


## The route: on the wizard at the start, on the soul at tick 270, back on the wizard at tick 540, bending to one side at right angles.
func _path() -> Dictionary:
	var checks := {}
	var start := Vector3(3.0, 0.0, 1.0)
	var soul := Vector3(33.0, 0.0, 1.0)
	var side := CarrierPath.side_velocity(start, soul, 0.75)
	checks["side_flat"] = is_zero_approx(side.y)
	checks["side_right_angle"] = absf(side.dot(soul - start)) < 0.001
	checks["side_length"] = absf(side.length() - 0.75 * 30.0) < 0.001
	checks["leaves_the_wizard"] = CarrierPath.out_at(start, soul, side, 0, 270).is_equal_approx(start)
	checks["reaches_the_soul"] = CarrierPath.out_at(start, soul, side, 270, 270).is_equal_approx(soul)
	var wizard := Vector3(3.5, 0.0, 1.5)
	checks["turns_on_the_soul"] = CarrierPath.back_at(soul, wizard, side, 0, 270).is_equal_approx(soul)
	checks["comes_home"] = CarrierPath.back_at(soul, wizard, side, 270, 270).is_equal_approx(wizard)
	var bulge := 0.0
	for tick in range(1, 270):
		bulge = maxf(bulge, absf(CarrierPath.out_at(start, soul, side, tick, 270).z - 1.0))
	checks["never_a_straight_line"] = bulge > 1.0
	var out_mid := CarrierPath.out_at(start, soul, side, 135, 270)
	var back_mid := CarrierPath.back_at(soul, start, side, 135, 270)
	checks["out_and_back_go_round_opposite_sides"] = signf(out_mid.z - 1.0) == -signf(back_mid.z - 1.0) and absf(out_mid.z - 1.0) > 1.0
	return _w.verdict("soul_path", checks)


## The scenes are what the spells say: pick a soul, the reach is the SpellType's range, no warnings, every kind is in the spawner.
func _scenes() -> Dictionary:
	var checks := {}
	var spawner := SpellSpawner.new()
	for tag in SOUL_SPELLS:
		var spell := GameData.spell(tag)
		var action := (spell.action.instantiate() as SpellAction) if spell != null and spell.action != null else null
		checks[tag + "_action"] = action != null and action.pick == SpellAction.Pick.SOUL and action._get_configuration_warnings().is_empty()
		if action is SoulAction:
			var scene := spawner.projectiles.get((action as SoulAction).carrier_kind) as PackedScene
			var carrier := scene.instantiate() if scene != null else null
			checks[tag + "_kind_in_spawner"] = carrier is SpellCarrier
			if carrier is SpellCarrier:
				var pulse := carrier.get_node("Pulse") as CarrierPulse
				checks[tag + "_reach_is_effect_range"] = absf(pulse.radius_m() - spell.effect_range_m) < 0.01
				checks[tag + "_pulse_ok"] = pulse._get_configuration_warnings().is_empty()
				checks[tag + "_fetch_ok"] = (carrier.get_node("Fetch") as SoulFetch)._get_configuration_warnings().is_empty()
				var wind: bool = tag == "dnws"
				checks[tag + "_who_it_touches"] = (pulse.affects == CarrierPulse.Affects.FOES) == wind and pulse.damage_foes == wind
			if carrier != null:
				carrier.free()
		if action != null:
			action.free()
	checks["animate_dead_kind_in_spawner"] = spawner.projectiles.has("AnimateDead")
	spawner.free()
	checks["wind_hurts_for_the_spell"] = GameData.spell("dnws").damage == 400 and GameData.spell("pmcd").damage == 0
	return _w.verdict("soul_scenes", checks)


## Soul Mole on a free soul at 30 m: born with the cast, on the soul at tick 270, takes it at the turn, stuns what it passes within 10 m
## (everybody but the wizard, even allies) only once the casting is over, hurts nobody, and the wizard collects the soul on the way home.
func _mole() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "james")
	await _land(wizard)
	var soul := _w.free_soul(Vector3(30.0, 0.0, 0.0))
	var near := _w.unit(Vector3(30.0, 0.0, 3.0), 3)
	var ally := _w.unit(Vector3(28.0, 0.0, 2.0), 2)
	var far := _w.unit(Vector3(30.0, 0.0, 70.0), 3)
	await _w.frames(3)
	var caster := wizard.get_node("Caster") as Caster
	var pool := wizard.get_node("ManaPool") as ManaPool
	var purse := wizard.get_node("SoulPurse")
	var mana := pool.current
	var souls := int(purse.get("count"))
	caster.request_cast("pmcd", soul.global_position, soul)
	var carrier := _w.carrier()
	checks["casting"] = caster.is_casting()
	checks["born_with_the_cast"] = carrier != null and carrier.frame == 0 and not carrier.armed and carrier.global_position.distance_to(wizard.global_position) < 0.5
	var seen := {"wizard_stunned": false, "early_stun": false, "near": false, "ally": false, "far": false, "armed_mana": 0.0, "on_soul": INF,
			"turn_carrier": false, "turn_slot": 0, "gap": 0.0, "last": 0, "armed_at": -1}
	for _i in 700:
		await _w.frames(1)
		if not is_instance_valid(carrier):
			break
		_watch_mole(carrier, soul, wizard, [near, ally, far], pool, seen)
	checks["info"] = seen
	checks["mana_spent_by_the_end_of_the_casting"] = absf(mana - float(seen["armed_mana"]) - 50.0) <= 1.0
	checks["armed_after_the_casting"] = int(seen["armed_at"]) > 0 and int(seen["armed_at"]) < 60
	checks["on_the_soul_at_270"] = float(seen["on_soul"]) < 0.1
	checks["soul_taken_at_the_turn"] = bool(seen["turn_carrier"]) and int(seen["turn_slot"]) == 1
	checks["soul_rides_the_carrier"] = float(seen["gap"]) < 1.0
	## SoulSystem takes the soul a tick before the carrier notices (its node comes first): the carrier's last tick is the pickup.
	checks["collected_on_the_way_home"] = int(seen["last"]) > 272 and int(seen["last"]) <= 540 and (not is_instance_valid(soul) or soul.state == Soul.State.COLLECTING)
	checks["trip_ends_by_540"] = int(seen["last"]) <= 540 and not is_instance_valid(carrier)
	checks["purse_gets_the_soul"] = int(purse.get("count")) == souls + 1
	checks["stuns_near"] = bool(seen["near"])
	checks["stuns_an_ally_too"] = bool(seen["ally"])
	checks["spares_far"] = not bool(seen["far"])
	checks["never_the_wizard"] = not bool(seen["wizard_stunned"])
	checks["no_stun_while_casting"] = not bool(seen["early_stun"])
	checks["no_damage"] = (near.get_node("Health") as Health).current == (near.get_node("Health") as Health).maximum
	for body: Node in [wizard, near, ally, far]:
		body.queue_free()
	return _w.verdict("soul_mole", checks)


func _watch_mole(carrier: SpellCarrier, soul: Soul, wizard: Node3D, bodies: Array, pool: ManaPool, seen: Dictionary) -> void:
	seen["last"] = carrier.frame
	if carrier.armed and int(seen["armed_at"]) < 0:
		seen["armed_at"] = carrier.frame
		seen["armed_mana"] = pool.current
	if _w.stunned(wizard):
		seen["wizard_stunned"] = true
	if not carrier.armed and (_w.stunned(bodies[0]) or _w.stunned(bodies[1])):
		seen["early_stun"] = true
	seen["near"] = bool(seen["near"]) or _w.stunned(bodies[0])
	seen["ally"] = bool(seen["ally"]) or _w.stunned(bodies[1])
	seen["far"] = bool(seen["far"]) or _w.stunned(bodies[2])
	if carrier.frame == 270:
		seen["on_soul"] = carrier.global_position.distance_to(soul.global_position)
	if carrier.frame == 272:
		seen["turn_carrier"] = soul.carrier == carrier and not soul.attached
		seen["turn_slot"] = soul.owner_slot
	if carrier.frame > 272 and is_instance_valid(soul) and soul.carrier == carrier:
		seen["gap"] = maxf(float(seen["gap"]), carrier.global_position.distance_to(soul.global_position))


## Soul Mole on the soul of an own corpse: at the turn the soul lets go of it and the corpse dissolves.
func _mole_corpse() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "james")
	await _land(wizard)
	var dead := await _w.corpse_with_soul(Vector3(25.0, 0.0, 0.0), 1)
	var soul := _w.soul_of(dead)
	checks["soul_on_the_corpse"] = soul != null and soul.attached and not soul.dropped
	var caster := wizard.get_node("Caster") as Caster
	checks["mole_accepts_it"] = caster.action_status("pmcd", soul.global_position, soul).is_empty()
	caster.request_cast("pmcd", soul.global_position, soul)
	var carrier := _w.carrier()
	var corpse := dead.corpse()
	var before := false
	var after := false
	for _i in 700:
		await _w.frames(1)
		if not is_instance_valid(carrier):
			break
		if carrier.frame == 268:
			before = corpse.dissolving
		if carrier.frame == 274:
			after = corpse.dissolving and not soul.attached and soul.corpse == null
	checks["corpse_whole_until_the_turn"] = not before
	checks["corpse_dissolves_at_the_turn"] = after
	wizard.queue_free()
	if is_instance_valid(dead):
		dead.queue_free()
	return _w.verdict("soul_mole_corpse", checks)


## Soul Wind from Stratos: the same trip, but it hurts and stuns every foe within 30 m once (400 of direct spell damage and a bolt each),
## and leaves allies, far bodies and the wizard alone.
func _wind() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "stratos")
	await _land(wizard)
	var soul := _w.free_soul(Vector3(30.0, 0.0, 0.0))
	var foe := _w.unit(Vector3(30.0, 0.0, 3.0), 3)
	var ally := _w.unit(Vector3(28.0, 0.0, 2.0), 2)
	var far := _w.unit(Vector3(30.0, 0.0, 70.0), 3)
	var twin := _w.unit(Vector3(600.0, 0.0, 600.0), 3)
	await _w.frames(3)
	var expected := (twin.get_node("Health") as Health).damage_typed(400.0, Health.DIRECT_SPELL, 1)
	var foe_health := foe.get_node("Health") as Health
	var ally_health := ally.get_node("Health") as Health
	var far_health := far.get_node("Health") as Health
	var wizard_health := wizard.get_node("Health") as Health
	var bolts := [0]
	var hits: Array[float] = []
	foe_health.hit.connect(func(amount: float, _slot: int, _full: bool) -> void: hits.append(amount))
	var count_bolt := func(kind: StringName, fx_name: String, _at: Vector3) -> void:
		if kind == FxBus.KIND_BEAM and fx_name == "soul_wind_bolt":
			bolts[0] += 1
	FxBus.played.connect(count_bolt)
	var caster := wizard.get_node("Caster") as Caster
	caster.request_cast("dnws", soul.global_position, soul)
	var carrier := _w.carrier()
	var stunned_foe := false
	var stunned_other := false
	for _i in 700:
		await _w.frames(1)
		if not is_instance_valid(carrier):
			break
		stunned_foe = stunned_foe or _w.stunned(foe)
		stunned_other = stunned_other or _w.stunned(ally) or _w.stunned(far) or _w.stunned(wizard)
	FxBus.played.disconnect(count_bolt)
	checks["info"] = {"expected": expected, "hits": hits, "bolts": bolts[0]}
	checks["expected_is_real"] = expected > 300.0
	checks["foe_hit_once"] = hits.size() == 1 and absf(hits[0] - expected) <= 0.5
	checks["foe_stunned"] = stunned_foe
	checks["one_bolt_for_the_foe"] = bolts[0] == 1
	checks["ally_untouched"] = ally_health.current == ally_health.maximum
	checks["far_untouched"] = far_health.current == far_health.maximum
	checks["wizard_untouched"] = wizard_health.current == wizard_health.maximum
	checks["only_the_foe_is_stunned"] = not stunned_other
	checks["soul_collected"] = is_instance_valid(soul) and soul.state == Soul.State.COLLECTING or not is_instance_valid(soul)
	for body: Node in [wizard, foe, ally, far, twin]:
		body.queue_free()
	return _w.verdict("soul_wind", checks)


## The cast is cut (the wizard dies while casting): the carrier is gone and the soul is left alone. A soul that another wizard takes before
## the turn ends the trip.
func _cancel() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "james")
	await _land(wizard)
	var soul := _w.free_soul(Vector3(30.0, 0.0, 0.0))
	await _w.frames(3)
	var caster := wizard.get_node("Caster") as Caster
	caster.request_cast("pmcd", soul.global_position, soul)
	var carrier := _w.carrier()
	checks["started"] = carrier != null
	await _w.frames(4)
	(wizard.get_node("Health") as Health).damage(99999.0, 3)
	await _w.frames(4)
	checks["carrier_gone_on_interruption"] = not is_instance_valid(carrier) or carrier.is_queued_for_deletion()
	checks["soul_left_alone"] = soul.carrier == null and soul.owner_slot == 0 and soul.state == Soul.State.NORMAL
	wizard.queue_free()
	var second := _w.wizard(1, Vector3(-60.0, 0.0, 0.0), "james")
	await _land(second)
	second.get_node("Caster").request_cast("pmcd", soul.global_position, soul)
	var walking := _w.carrier()
	await _w.frames(100)
	checks["walks_while_the_soul_is_there"] = is_instance_valid(walking) and walking.frame > 90
	soul.state = Soul.State.COLLECTING
	await _w.frames(3)
	checks["ends_when_the_soul_is_taken"] = not is_instance_valid(walking) or walking.is_queued_for_deletion()
	second.queue_free()
	soul.queue_free()
	return _w.verdict("soul_cancel", checks)


## What the three spells refuse: a body, a dropped soul, an enemy's soul, a soul out of range, no mana. A good soul passes.
func _refusals() -> Dictionary:
	var checks := {}
	var wizards := {}
	for tag in SOUL_SPELLS:
		wizards[tag] = _w.wizard(1, Vector3.ZERO if tag == "pmcd" else Vector3(0.0, 0.0, 200.0 if tag == "dnws" else -200.0), SOUL_SPELLS[tag])
	for tag in wizards:
		await _land(wizards[tag])
	var enemy_dead := await _w.corpse_with_soul(Vector3(10.0, 0.0, 10.0), 3)
	var enemy_soul := _w.soul_of(enemy_dead)
	for tag in ["pmcd", "dnws"]:
		var wizard := wizards[tag] as WizardBody
		var caster := wizard.get_node("Caster") as Caster
		var at := wizard.global_position
		var good := _w.free_soul(at + Vector3(20.0, 0.0, 0.0))
		var dropped := _w.free_soul(at + Vector3(0.0, 0.0, 20.0))
		dropped.dropped = true
		var body := _w.unit(at + Vector3(0.0, 0.0, -20.0), 3)
		var out := _w.free_soul(at + Vector3(350.0, 0.0, 0.0))
		await _w.frames(2)
		checks[tag + "_good_soul"] = caster.action_status(tag, good.global_position, good).is_empty()
		checks[tag + "_not_a_body"] = caster.action_status(tag, body.global_position, body) == SpellAction.BAD_TARGET
		checks[tag + "_not_nothing"] = caster.action_status(tag, at, null) == SpellAction.BAD_TARGET
		checks[tag + "_not_a_dropped_soul"] = caster.action_status(tag, dropped.global_position, dropped) == SpellAction.BAD_TARGET
		checks[tag + "_out_of_range"] = caster.action_status(tag, out.global_position, out) == SpellAction.OUT_OF_RANGE
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.current = 0.0
		checks[tag + "_no_mana"] = caster.action_status(tag, good.global_position, good) == SpellAction.NO_MANA
		pool.current = pool.maximum
	checks["mole_not_an_enemy_soul"] = enemy_soul != null and (wizards["pmcd"].get_node("Caster") as Caster).action_status("pmcd", enemy_soul.global_position, enemy_soul) == SpellAction.BAD_TARGET
	for tag in wizards:
		wizards[tag].queue_free()
	return _w.verdict("soul_refusals", checks)


## The AI has no use for these (the original has none either): they rate nothing and the other spells keep their evaluator.
func _ai() -> Dictionary:
	var checks := {}
	for tag in SOUL_SPELLS:
		checks[tag + "_rates_nothing"] = AiSpellEval.rating_fn(GameData.spell(tag)) == AiSpellEval.FN_NONE
	checks["old_spells_unchanged"] = AiSpellEval.rating_fn(GameData.spell("kcor")) == AiSpellEval.FN_SINGLE
	return _w.verdict("soul_ai", checks)


func _land(wizard: WizardBody) -> void:
	await _w.until(func() -> bool: return wizard.is_on_floor(), 180)
