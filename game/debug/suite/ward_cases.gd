extends RefCounted

## RFC-061b cases of rules_suite: the five level-2 wards of the wizard (Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective
## Swarm) through Wards, Ward, BodyAura and WardAction: the damage each one lets through, how long it lasts, what Fireform, the Swarm and
## the Air Shield do to the bodies around, who is protected from Freeze, Petrify and Pull, the cast from the book of each god and what
## the AI does with them. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.
## Aura time is driven by calling `_physics_process` with a chosen delta, so a case does not wait seconds.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const WARDS: Array[String] = ["niks", "dlhs", "mrfe", "mrff", "rwsp"]
const GODS := {"niks": "james", "dlhs": "stratos", "mrfe": "persephone", "mrff": "pyro", "rwsp": "charnel"}
## How much of a 1000 direct-spell hit each ward lets through (REA: 0.25, 0.5, immune, 1, 0.75).
const SPELL_FACTOR := {"niks": 0.25, "dlhs": 0.5, "mrfe": 0.0, "mrff": 1.0, "rwsp": 0.75}
const TOLERANCE := 0.01

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "WardCases"
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
	SideRelations.set_rows(_rows(), 3)
	var out := {}
	out["ward_scenes"] = await _scenes()
	out["ward_numbers"] = await _numbers()
	out["ward_duration"] = await _duration()
	out["ward_fireform"] = await _fireform()
	out["ward_swarm"] = await _swarm()
	out["ward_air_push"] = await _air_push()
	out["ward_shielded"] = await _shielded()
	out["ward_cast"] = await _cast()
	out["ward_ai"] = await _ai()
	SideRelations.refresh()
	_root.queue_free()
	return out


## The five wards sit on the wizard with their spell, a look and a socket for the body and the health.
func _scenes() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "james")
	await _frames(2)
	var wards := Wards.of(wizard)
	checks["wards_node"] = wards != null
	checks["skin_is_stone"] = wards.ward_for(GameData.spell("niks")).stone_skin and not wards.stone_skin()
	for tag in WARDS:
		var ward := wards.ward_for(GameData.spell(tag)) if wards else null
		checks[tag + "_ward"] = ward != null and ward.body == wizard and ward.health != null and (ward.look != null or tag != "dlhs")
		checks[tag + "_off"] = ward != null and not ward.is_on() and not ward.shown
		checks[tag + "_no_warnings"] = ward != null and ward._get_configuration_warnings().is_empty()
		var aura := ward.find_child("Aura", false, false) if ward else null
		checks[tag + "_aura_no_warnings"] = aura == null or (aura as BodyAura)._get_configuration_warnings().is_empty()
	var unit := _unit(Vector3(50.0, 0.0, 0.0), 1)
	await _frames(1)
	checks["life_shield_is_ward"] = LifeShield.of(unit) != null
	unit.queue_free()
	checks["only_life_shield_is_not_spell"] = wards.ward_for(null) == null
	wizard.queue_free()
	return _verdict("ward_scenes", checks)


## A hit of 1000 leaves what the REA says: x0.25, x0.5 (x0.25 at range), x0, x1, x0.75; a hit that pierces shields skips all but the
## immunity.
func _numbers() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "james")
	await _frames(2)
	var health := wizard.get_node("Health") as Health
	var wards := Wards.of(wizard)
	var base := _hit(health, Health.DIRECT_SPELL, false)
	var base_ranged := _hit(health, Health.DIRECT_RANGED, false)
	checks["base_hits"] = base > 0.0 and base_ranged > 0.0
	for tag in WARDS:
		var ward := wards.ward_for(GameData.spell(tag))
		ward.start_for(GameData.spell(tag))
		checks[tag + "_spell"] = _near(_hit(health, Health.DIRECT_SPELL, false), base * float(SPELL_FACTOR[tag]))
		checks[tag + "_melee_splash"] = _near(_hit(health, Health.SPLASH_SPELL, false), _hit_off(health, wards, ward, Health.SPLASH_SPELL) * float(SPELL_FACTOR[tag]))
		var ranged_expect := base_ranged * float(SPELL_FACTOR[tag]) * (0.5 if tag == "dlhs" else 1.0)
		checks[tag + "_ranged"] = _near(_hit(health, Health.DIRECT_RANGED, false), ranged_expect)
		var pierce := _hit(health, Health.DIRECT_SPELL, true)
		checks[tag + "_pierce"] = _near(pierce, 0.0 if tag == "mrfe" else base)
		ward.stop("caso")
	checks["melee_path_immune"] = true
	var ethereal := wards.ward_for(GameData.spell("mrfe"))
	ethereal.start_for(GameData.spell("mrfe"))
	var before := health.current
	checks["melee_path_immune"] = health.damage(500.0, 3) == 0.0 and health.current == before
	ethereal.stop("caso")
	wizard.queue_free()
	return _verdict("ward_numbers", checks)


## Duration in ticks = duration x 60; it ends by time, and on the death of the body every ward goes off.
func _duration() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "james")
	await _frames(2)
	var wards := Wards.of(wizard)
	for tag in WARDS:
		var spell := GameData.spell(tag)
		var ward := wards.ward_for(spell)
		checks[tag + "_started"] = ward.start_for(spell)
		checks[tag + "_second_refused"] = not ward.start_for(spell)
		checks[tag + "_ticks"] = absi(ward.ticks_left() - roundi(spell.duration * 60.0)) <= 1 and ward.shown
		if tag == "mrfe":
			ward.stop("caso")
	var ward := wards.ward_for(GameData.spell("dlhs"))
	ward.stop("caso")
	checks["short_start"] = ward.start(5)
	await _frames(8)
	checks["ends_by_time"] = not ward.is_on() and not ward.shown
	var shown_on_death := true
	wizard.get_node("Health").damage(99999.0, 3)
	for tag in WARDS:
		shown_on_death = shown_on_death and not wards.ward_for(GameData.spell(tag)).shown
	checks["death_turns_all_off"] = shown_on_death
	wizard.queue_free()
	return _verdict("ward_duration", checks)


## Fireform: 250 per second to a foe whose box is 0.5 m from the wizard's, shielded or not (10 s: 2500 x its resistance); an ally and
## a body 20 m away take nothing.
func _fireform() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "pyro")
	var foe := _unit(Vector3(2.0, 0.0, 0.0), 3)
	var ally := _unit(Vector3(-2.0, 0.0, 0.0), 2)
	var far := _unit(Vector3(20.0, 0.0, 0.0), 3)
	await _land(wizard)
	var shield := LifeShield.of(foe)
	shield.start(100000)
	var spell := GameData.spell("mrff")
	var ward := Wards.of(wizard).ward_for(spell)
	var aura := ward.find_child("Aura", false, false) as BodyAura
	var foe_health := foe.get_node("Health") as Health
	var resistance := foe_health.resistance(Health.DIRECT_SPELL)
	checks["victim_takes_spells"] = resistance > 0.0
	checks["gap_inside_reach"] = BodyAura.box_gap(BodyNudge.box(wizard), BodyNudge.box(foe)) < 5.0
	checks["far_outside_reach"] = BodyAura.box_gap(BodyNudge.box(wizard), BodyNudge.box(far)) > 5.0
	_full(foe_health, 10000.0)
	_full(ally.get_node("Health"), 10000.0)
	_full(far.get_node("Health"), 10000.0)
	aura._physics_process(1.0)
	checks["off_does_nothing"] = foe_health.current == foe_health.maximum
	ward.start_for(spell)
	for _second in 10:
		aura._physics_process(1.0)
	var taken := foe_health.maximum - foe_health.current
	checks["pierces_life_shield"] = absf(taken - 2500.0 * resistance) <= 25.0 * resistance
	checks["ally_untouched"] = (ally.get_node("Health") as Health).current == 10000.0
	checks["far_untouched"] = (far.get_node("Health") as Health).current == 10000.0
	checks["wizard_not_hurt"] = (wizard.get_node("Health") as Health).current == (wizard.get_node("Health") as Health).maximum
	for node in [wizard, foe, ally, far]:
		node.queue_free()
	return _verdict("ward_fireform", checks)


## Protective Swarm: 75 per second to a foe within 4 m, and the wizard heals half of what it took.
func _swarm() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "charnel")
	var foe := _unit(Vector3(2.0, 0.0, 0.0), 3)
	var far := _unit(Vector3(12.0, 0.0, 0.0), 3)
	await _land(wizard)
	var spell := GameData.spell("rwsp")
	var ward := Wards.of(wizard).ward_for(spell)
	var aura := ward.find_child("Aura", false, false) as BodyAura
	var foe_health := foe.get_node("Health") as Health
	var own := wizard.get_node("Health") as Health
	_full(foe_health, 10000.0)
	_full(far.get_node("Health"), 10000.0)
	own.current = 2000.0
	ward.start_for(spell)
	aura._physics_process(1.0)
	var taken := foe_health.maximum - foe_health.current
	var expected := 75.0 * foe_health.resistance(Health.DIRECT_SPELL) * foe_health.shield_factor(Health.DIRECT_SPELL)
	checks["stings_75"] = taken > 0.0 and absf(taken - expected) <= 0.5
	checks["heals_half"] = absf(own.current - 2000.0 - taken * 0.5) <= 0.5
	checks["far_untouched"] = (far.get_node("Health") as Health).current == 10000.0
	for node in [wizard, foe, far]:
		node.queue_free()
	return _verdict("ward_swarm", checks)


## Air Shield: a foe at 3 m is pushed to the edge of the 5 m reach within a second (the push falls to 0 at the reach, so it settles at
## the edge: it never reaches 5 m exactly); an own creature next to it does not move. Allies of another seat are pushed too
## (the shield pushes every body of another side).
func _air_push() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "stratos")
	var foe := _unit(Vector3(3.0, 0.0, 0.0), 3)
	var own := _unit(Vector3(0.0, 0.0, 3.0), 1)
	await _land(wizard)
	var spell := GameData.spell("dlhs")
	var ward := Wards.of(wizard).ward_for(spell)
	var aura := ward.find_child("Aura", false, false) as BodyAura
	var from := foe.global_position
	aura._physics_process(1.0 / 60.0)
	checks["off_does_not_push"] = foe.global_position.is_equal_approx(from)
	ward.start_for(spell)
	var steps := 0
	while steps < 60 and foe.global_position.distance_to(wizard.global_position) < 4.9:
		aura._physics_process(1.0 / 60.0)
		steps += 1
	var edge := foe.global_position.distance_to(wizard.global_position)
	checks["foe_at_the_edge_in_1s"] = edge >= 4.9 and edge <= 5.0 and steps < 60
	checks["own_stays"] = own.global_position.is_equal_approx(Vector3(0.0, own.global_position.y, 3.0))
	for node in [wizard, foe, own]:
		node.queue_free()
	return _verdict("ward_air_push", checks)


## With any of the five on the wizard is shielded: Freeze, Petrify and Pull refuse him. Without, Petrify works.
func _shielded() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "james")
	var puller := _unit(Vector3(10.0, 0.0, 0.0), 3)
	await _frames(2)
	var wards := Wards.of(wizard)
	var afflictions := wizard.get_node("Afflictions") as Afflictions
	var petrified := wizard.get_node("Afflictions/Petrified") as Petrified
	var frozen := wizard.get_node("Afflictions/Frozen") as Frozen
	var pull := _pull_of(puller)
	checks["none_not_shielded"] = not wards.shielded() and not afflictions.cc_protected()
	for tag in WARDS:
		var spell := GameData.spell(tag)
		var ward := wards.ward_for(spell)
		ward.start_for(spell)
		checks[tag + "_shielded"] = wards.shielded() and afflictions.cc_protected()
		checks[tag + "_no_petrify"] = not petrified.petrify(60)
		checks[tag + "_no_freeze"] = not frozen.try_freeze_with_cooldown(GameData.spell("zerf"), 3)
		checks[tag + "_no_pull"] = not pull.applicable(wizard)
		ward.stop("caso")
	checks["control_pull"] = pull.applicable(wizard)
	wizard.queue_free()
	puller.queue_free()
	return _verdict("ward_shielded", checks)


## The key of the level-2 spell of each god through Caster: the cast spends 400 mana, sets the cooldown and, when the casting time ends,
## the ward is on for the duration. Already on is BAD_TARGET (nothing spent); Ethereal fades the body.
func _cast() -> Dictionary:
	var checks := {}
	for tag in WARDS:
		var god: String = GODS[tag]
		var wizard := _wizard(1, Vector3.ZERO, god, 3)
		await _frames(2)
		var caster := wizard.get_node("Caster") as Caster
		var spell := GameData.spell(tag)
		var action := caster.action_for(tag)
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.maximum = 10000.0
		pool.current = 5000.0
		checks[tag + "_in_book"] = caster.spellbook.index_of(tag) >= 0
		var entry := caster.spellbook.spell_by_tag(tag)
		if action == null:
			wizard.queue_free()
			continue
		checks[tag + "_action"] = action is WardAction and action.pick == SpellAction.Pick.SELF
		checks[tag + "_arm_ok"] = caster.arm_status(caster.spellbook.index_of(tag)).is_empty()
		caster.request_cast(tag, Vector3.ZERO, null)
		var ward := Wards.of(wizard).ward_for(spell)
		checks[tag + "_casting"] = caster.is_casting() and not ward.is_on()
		for _frame in 140:
			await _frames(1)
			if ward.is_on():
				break
		checks[tag + "_on"] = ward.is_on() and Wards.of(wizard).shielded()
		checks[tag + "_mana"] = absf(5000.0 - pool.current - 400.0) <= 2.0 or pool.current < 4700.0
		checks[tag + "_cooling"] = caster.spellbook.cooldown(caster.spellbook.index_of(tag)) > 0.0
		var again := caster.action_for(tag).check(wizard, spell, Vector3.ZERO, null, "")
		checks[tag + "_again_refused"] = again.status == SpellAction.BAD_TARGET
		if tag == "mrfe":
			await _frames(40)
			var visual := wizard.get_node("GhostForm").visual as GeometryInstance3D
			checks["mrfe_fades"] = visual.transparency > 0.6
		wizard.queue_free()
		await _frames(1)
	return _verdict("ward_cast", checks)


## The AI rates its ward by the foes near it: Skin of Stone (James) is worth the wizard's rating with two known foes within
## guard_threat_m and the ward off; nothing with one, with none far away, or with the ward on. The support phase picks it.
func _ai() -> Dictionary:
	var checks := {}
	var perception := AiPerception.new()
	perception.name = "WardCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "james", 3)
	var near_a := _unit(Vector3(-395.0, 0.0, -400.0), 3)
	var near_b := _unit(Vector3(-400.0, 0.0, -390.0), 3)
	var far := _unit(Vector3(-300.0, 0.0, -400.0), 3)
	await _frames(2)
	var stance := AiStance.new()
	stance.recs[0].manaliths = 1
	var eval := AiSpellEval.new(perception, stance, null, perception.profile)
	var spell := GameData.spell("niks")
	var track := perception.add_node(wizard, &"event")
	var a := perception.add_node(near_a, &"event")
	checks["tracked"] = track != null and a != null
	if track != null and a != null:
		track.cached_rate = 1.0
		checks["fn_is_guard"] = AiSpellEval.rating_fn(spell) == AiSpellEval.FN_GUARD
		checks["accepted_by_support"] = AiSpellEval.accepts(spell, AiSpellEval.SUPPORT_MASK) and not AiSpellEval.accepts(spell, AiSpellEval.ATTACK_MASK)
		checks["one_foe_zero"] = AiGuard.rate(spell, track, perception, eval.tactics) == 0.0
		var b := perception.add_node(near_b, &"event")
		perception.add_node(far, &"event")
		checks["two_foes_worth"] = AiGuard.rate(spell, track, perception, eval.tactics) == 1.0
		(wizard.get_node("ManaPool") as ManaPool).maximum = 10000.0
		track.spell_accs = [{"spell": spell, "fn": AiSpellEval.rating_fn(spell)}]
		var found := eval.find_best(track, track, AiSpellEval.SUPPORT_MASK)
		checks["support_picks_it"] = found.get("spell") == spell
		b.cached_rate = 1.0
		near_b.global_position = Vector3(-300.0, 0.0, -300.0)
		b.cur_pos = near_b.global_position
		checks["foe_moved_away_zero"] = AiGuard.rate(spell, track, perception, eval.tactics) == 0.0
		b.cur_pos = near_b.global_position
		near_b.global_position = Vector3(-400.0, 0.0, -390.0)
		b.cur_pos = near_b.global_position
		var ward := Wards.of(wizard).ward_for(spell)
		ward.start_for(spell)
		checks["ward_on_zero"] = AiGuard.rate(spell, track, perception, eval.tactics) == 0.0
		ward.stop("caso")
	var other := GameData.spell("dlhs")
	checks["other_god_book"] = Wards.of(wizard).ward_for(other) != null and AiSpellEval.rating_fn(other) == AiSpellEval.FN_GUARD
	checks["tactics_knobs"] = eval.tactics.guard_threat_m == 25.0 and eval.tactics.guard_min_foes == 2
	checks["old_spells_unchanged"] = AiSpellEval.rating_fn(GameData.spell("kcor")) == AiSpellEval.FN_SINGLE and AiSpellEval.rating_fn(GameData.spell("laeh")) == AiSpellEval.FN_HEAL
	stance.free()
	for node: Node in [perception, wizard, near_a, near_b, far]:
		node.queue_free()
	return _verdict("ward_ai", checks)


## A web pull (Gremlin) of `user`, to ask whom it may pull.
func _pull_of(user: UnitBody) -> Pull:
	var pull := (load("res://scenes/units/abilities/web_pull.tscn") as PackedScene).instantiate() as Pull
	pull.user = user
	user.add_child(pull)
	return pull


## One hit of 1000 from seat 3 on a full bar: what it took (the bar is refilled).
func _hit(health: Health, kind: StringName, pierce: bool) -> float:
	health.current = health.maximum
	return health.damage_typed(1000.0, kind, 3, false, pierce)


## The same hit with `ward` off for a moment.
func _hit_off(health: Health, _wards: Wards, ward: Ward, kind: StringName) -> float:
	var left := ward.ticks_left()
	ward.stop("caso")
	var taken := _hit(health, kind, false)
	ward.start(left)
	return taken


func _full(health: Health, amount: float) -> void:
	health.maximum = amount
	health.current = amount


func _near(value: float, expected: float) -> bool:
	return absf(value - expected) <= maxf(0.5, absf(expected) * TOLERANCE)


func _wizard(slot: int, at: Vector3, god: String, level := 1) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = god
	wizard.level = level
	wizard.position = at
	_root.add_child(wizard)
	## The wizard reads its seat's god when it enters; the case says it again.
	wizard.god = god
	(wizard.get_node("Health") as Health).setup(10000.0)
	return wizard


func _unit(at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.creature_tag = "nmuh"
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.idle_aggro = false
	unit.position = at
	_root.add_child(unit)
	return unit


## Three sides: seats 1 and 2 are allies, seat 3 is the enemy of both.
func _rows() -> Array:
	return [
		{"id": 0, "allies": 0b011, "enemies": 0b100, "assignment": 1},
		{"id": 1, "allies": 0b011, "enemies": 0b100, "assignment": 2},
		{"id": 2, "allies": 0b100, "enemies": 0b011, "assignment": 3},
	]


## The wizard falls from where he spawns: waits until he stands (at most 3 s).
func _land(wizard: WizardBody) -> void:
	for _i in 180:
		await _frames(1)
		if wizard.is_on_floor():
			return


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("ward_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
