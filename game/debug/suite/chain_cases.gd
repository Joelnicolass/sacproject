extends RefCounted

## RFC-061e cases of rules_suite: the four jumping and guided spells of the wizard (Chain Lightning ntlc, Rainbow wobr, Dragonfire rifd,
## Halo of Earth olah) through ChainHop, LaunchAction, CarrierAction, SpellCarrier and HaloOfEarth: the radius that shrinks, who is picked,
## 7 hits of 600 every 20 ticks, 6 full cures, the dragon's 5 targets, its speed, burn and shrinking, the 6 rocks and when they come out.
## Every number is read in ticks of MatchClock (the suite runs at any fixed fps). No network: the server paths run as solo. `run(host)`
## adds its own bodies, the two spawners and their containers, and removes them.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const TOLERANCE := 0.01
const ORIGIN := Vector3(0.0, 0.0, 0.0)

var _host: Node3D
var _root: Node3D
var _shots: Node3D
var _spells: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "ChainCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 2.0, 1200.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_shots = _container("Shots", ShotSpawner.new(), "ShotSpawner")
	_spells = _container("Spells", SpellSpawner.new(), "SpellSpawner")
	_host.add_child(_root)
	SideRelations.set_rows(_rows(), 3)
	var out := {}
	out["chain_scenes"] = await _scenes()
	out["chain_radius"] = _radius()
	out["chain_pick"] = await _pick()
	out["chain_lightning"] = await _lightning()
	out["chain_rainbow"] = await _rainbow()
	out["chain_halo_rocks"] = await _halo_formula()
	out["chain_halo"] = await _halo()
	out["chain_halo_abort"] = await _halo_abort()
	out["chain_dragon_burn"] = await _dragon_burn()
	out["chain_dragon"] = await _dragon()
	out["chain_dragon_alone"] = await _dragon_alone()
	out["chain_ai"] = await _ai()
	SideRelations.refresh()
	_root.queue_free()
	return out


## The four spells have their action scene and it asks for nothing it lacks; the beams and the sound keys they use exist.
func _scenes() -> Dictionary:
	var checks := {}
	for pair in [["ntlc", LaunchAction, SpellAction.Pick.GROUND], ["wobr", LaunchAction, SpellAction.Pick.GROUND],
			["olah", LaunchAction, SpellAction.Pick.SELF], ["rifd", CarrierAction, SpellAction.Pick.GROUND]]:
		var tag: String = pair[0]
		var spell := GameData.spell(tag)
		var action := spell.action.instantiate() as SpellAction if spell != null and spell.action != null else null
		checks[tag + "_action_scene"] = action != null and is_instance_of(action, pair[1])
		if action == null:
			continue
		action.tag = tag
		checks[tag + "_no_warnings"] = action._get_configuration_warnings().is_empty()
		checks[tag + "_pick"] = action.pick == pair[2]
		action.free()
	checks["rainbow_beam_is_arc"] = FxBus.beam_type("rainbow_arc") != null and FxBus.beam_type("rainbow_arc").path == BeamType.Path.ARC
	checks["rainbow_arc_numbers"] = FxBus.beam_type("rainbow_arc").segments == 31 and absf(FxBus.beam_type("rainbow_arc").width_m - 0.7) < 0.001
	checks["ltng_knob_exists"] = FxBus.beam_type("lightning_ltng") != null and FxBus.beam_type("lightning_ltng").atlas_tag == "ltng"
	checks["dragon_kind"] = (_spells.get_parent().get_node("SpellSpawner") as SpellSpawner).projectiles.has("Dragonfire")
	var caster_wizard := _wizard(1, ORIGIN, "stratos", 5)
	await _frames(2)
	var bolts := (load("res://scenes/spells/chain/cast_bolts.tscn") as PackedScene).instantiate() as CastBolts
	var glow := (load("res://scenes/spells/chain/cast_glow.tscn") as PackedScene).instantiate() as CastGlow
	_root.add_child(bolts)
	_root.add_child(glow)
	bolts.play({"ticks": 5, "wizard": str(caster_wizard.get_path())})
	glow.play({"ticks": 5, "wizard": str(caster_wizard.get_path())})
	checks["cast_scenes_play"] = bolts.is_physics_processing() and glow.is_physics_processing()
	await _frames(12)
	checks["cast_bolts_free_themselves"] = not is_instance_valid(bolts) or bolts.is_queued_for_deletion()
	checks["cast_glow_stops"] = not glow.is_physics_processing()
	glow.queue_free()
	caster_wizard.queue_free()
	for god in ["stratos", "persephone", "pyro", "james"]:
		var tags: Array = []
		for entry in GameData.book(god, 5)["spells"]:
			tags.append(entry.tag)
		var own := {"stratos": "ntlc", "persephone": "wobr", "pyro": "rifd", "james": "olah"}[god] as String
		checks[god + "_book_has_" + own] = tags.has(own)
	return _verdict("chain_scenes", checks)


## (6 - n) / 6 of the range after n hits: 50, 41.67, 33.33, 25, 16.67 and 8.33 m; whole with no steps.
func _radius() -> Dictionary:
	var checks := {}
	var expected: Array[float] = [50.0, 41.6667, 33.3333, 25.0, 16.6667, 8.3333]
	for n in 6:
		checks["radius_%d" % n] = absf(ChainHop.radius_for(50.0, n, 6) - expected[n]) < 0.001
	checks["radius_fixed_without_steps"] = ChainHop.radius_for(50.0, 4, 0) == 50.0
	checks["radius_never_negative"] = ChainHop.radius_for(50.0, 9, 6) == 0.0
	return _verdict("chain_radius", checks)


## Who is next: the nearest live non-ally not yet hit inside the radius; the lowest health among allies for Rainbow.
func _pick() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "stratos", 5)
	var from := Vector3(-400.0, 0.0, -300.0)
	var near := _unit(from + Vector3(20.0, 0.0, 0.0), 3)
	var far := _unit(from + Vector3(45.0, 0.0, 0.0), 3)
	var dead := _unit(from + Vector3(10.0, 0.0, 0.0), 3)
	var ally := _unit(from + Vector3(5.0, 0.0, 0.0), 2)
	var hurt_ally := _unit(from + Vector3(30.0, 0.0, 0.0), 2)
	await _frames(2)
	dead.get_node("Health").damage(99999.0, 3)
	(hurt_ally.get_node("Health") as Health).current = 1.0
	var hop := ChainHop.new()
	_root.add_child(hop)
	hop.begin_cast(wizard, GameData.spell("ntlc"), null, from, 0)
	checks["nearest_live_foe"] = hop.pick_next(from, 0) == near
	checks["ally_and_dead_skipped"] = hop.pick_next(from, 0) != ally and hop.pick_next(from, 0) != dead
	checks["add_hit_counts"] = hop.add_hit(near) and hop.hit_count() == 1 and hop.has_hit(near)
	checks["hit_not_picked_again"] = hop.pick_next(from, 0) == far
	checks["radius_n1_excludes_45m"] = hop.pick_next(from, 1) == null
	checks["radius_n0_includes_45m"] = hop.pick_next(from, 0) == far
	hop.hits = 2
	checks["full_chain_refuses"] = hop.add_hit(far) and not hop.add_hit(ally)
	var rainbow := ChainHop.new()
	rainbow.allies = true
	rainbow.order = ChainPick.Order.LOWEST_HEALTH
	_root.add_child(rainbow)
	rainbow.begin_cast(wizard, GameData.spell("wobr"), null, from, 0)
	checks["ally_with_lowest_health"] = rainbow.pick_next(from, 0) == hurt_ally
	checks["foe_is_not_an_ally"] = rainbow.pick_next(from, 0) != near
	for node: Node in [wizard, near, far, dead, ally, hurt_ally, hop, rainbow]:
		node.queue_free()
	return _verdict("chain_pick", checks)


## Chain Lightning through the book: 9 foes in a row 6 m apart, 7 hits of 600 every 20 ticks, an ally and a far foe untouched.
func _lightning() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "stratos", 5)
	var foes: Array[UnitBody] = []
	for i in 9:
		foes.append(_unit(Vector3(20.0 + 6.0 * i, 0.0, 0.0), 3))
	var ally := _unit(Vector3(29.0, 0.0, 4.0), 2)
	var far := _unit(Vector3(200.0, 0.0, 0.0), 3)
	await _land(wizard)
	for body: UnitBody in foes + [ally, far]:
		_full(body.get_node("Health"), 10000.0)
	var caster := wizard.get_node("Caster") as Caster
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0
	var hurts := _watch(foes + [ally, far])
	checks["in_book"] = caster.spellbook.index_of("ntlc") >= 0
	caster.request_cast("ntlc", foes[0].global_position, foes[0])
	checks["casting"] = caster.is_casting()
	var hop := _first(_shots, ChainHop) as ChainHop
	checks["hop_made_at_start"] = hop != null and hop.spell != null and hop.spell.tag == "ntlc"
	var ticks: Array[int] = []
	var bodies: Array[Node3D] = []
	if hop != null:
		hop.landed.connect(func(body: Node3D, _point: Vector3, _index: int) -> void:
			ticks.append(MatchClock.now())
			bodies.append(body))
	for _frame in 6000:
		await _frames(1)
		if hop == null or not is_instance_valid(hop):
			break
	await _frames(MatchClock.ticks_for(0.5))
	checks["seven_landings"] = bodies.size() == 7
	var resistance := (foes[0].get_node("Health") as Health).resistance(Health.DIRECT_SPELL)
	checks["resistance_known"] = resistance > 0.0
	for i in 9:
		var took := _taken(hurts, foes[i])
		var expected := 600.0 * resistance if i < 7 else 0.0
		checks["foe_%d_%s" % [i, "hit_600" if i < 7 else "untouched"]] = absf(took - expected) <= maxf(0.5, expected * TOLERANCE)
		checks["foe_%d_hit_once" % i] = (hurts[foes[i]] as Array).size() == (1 if i < 7 else 0)
	checks["landed_in_row_order"] = _same(bodies, foes.slice(0, 7))
	checks["ally_untouched"] = _taken(hurts, ally) == 0.0
	checks["far_untouched"] = _taken(hurts, far) == 0.0
	var spaced := ticks.size() == 7
	for i in range(1, ticks.size()):
		spaced = spaced and absi((ticks[i] - ticks[i - 1]) - MatchClock.ticks_for(20.0 / 60.0)) <= 1
	checks["one_jump_every_20_ticks"] = spaced
	checks["mana_spent"] = absf(5000.0 - pool.current - 800.0) <= 5.0 or pool.current < 4300.0
	checks["cooldown_set"] = caster.spellbook.cooldown(caster.spellbook.index_of("ntlc")) > 0.0
	for node: Node in foes + [wizard, ally, far]:
		node.queue_free()
	return _verdict("chain_lightning", checks)


## Rainbow: 7 hurt allies; the click lands on the one at 70 %, then the lowest health first: 6 end full, the 7th is not touched.
func _rainbow() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "persephone", 5)
	var allies: Array[UnitBody] = []
	var health_now: Array[float] = [700.0, 100.0, 200.0, 300.0, 400.0, 500.0, 600.0]
	for i in 7:
		var angle := TAU * float(i) / 7.0
		allies.append(_unit(Vector3(12.0 + 3.0 * cos(angle), 0.0, 3.0 * sin(angle)), 2))
	await _land(wizard)
	for i in 7:
		var health := allies[i].get_node("Health") as Health
		_full(health, 1000.0)
		health.current = health_now[i]
	var caster := wizard.get_node("Caster") as Caster
	_mana(wizard)
	checks["in_book"] = caster.spellbook.index_of("wobr") >= 0
	caster.request_cast("wobr", allies[0].global_position, allies[0])
	var hop := _first(_shots, ChainHop) as ChainHop
	checks["hop_made_at_start"] = hop != null
	var ticks: Array[int] = []
	var bodies: Array[Node3D] = []
	if hop != null:
		hop.landed.connect(func(body: Node3D, _point: Vector3, _index: int) -> void:
			ticks.append(MatchClock.now())
			bodies.append(body))
	for _frame in 8000:
		await _frames(1)
		if hop == null or not is_instance_valid(hop):
			break
	for _frame in 400:
		await _frames(1)
		var all_cured := true
		for i in 6:
			all_cured = all_cured and (allies[i].get_node("Health") as Health).is_full()
		if all_cured:
			break
	checks["six_landings"] = bodies.size() == 6
	checks["order_click_then_lowest_health"] = _same(bodies, allies.slice(0, 6))
	for i in 6:
		var health := allies[i].get_node("Health") as Health
		checks["ally_%d_full" % i] = health.current == health.maximum
	var last := allies[6].get_node("Health") as Health
	checks["seventh_untouched"] = allies[6].get_node_or_null("HealEffect") == null and not last.is_full()
	var spaced := ticks.size() == 6
	for i in range(1, ticks.size()):
		spaced = spaced and absi((ticks[i] - ticks[i - 1]) - MatchClock.ticks_for(64.0 / 60.0)) <= 1
	checks["one_arc_every_64_ticks"] = spaced
	checks["cure_is_the_maximum"] = (allies[0].get_node("Health") as Health).maximum == 1000.0
	for node: Node in allies + [wizard]:
		node.queue_free()
	return _verdict("chain_rainbow", checks)


## The rocks out by the share of the casting that has gone: floor((p + 0.1) x 6), all six at the end.
func _halo_formula() -> Dictionary:
	var checks := {}
	var halo := (load("res://scenes/units/abilities/halo_of_earth_spell.tscn") as PackedScene).instantiate() as HaloOfEarth
	halo.set("_armed", false)
	halo.set("_cast_ticks", 100)
	var wanted := {0: 0, 6: 0, 7: 1, 23: 1, 24: 2, 40: 3, 57: 4, 74: 5, 90: 6, 100: 6}
	for elapsed: int in wanted:
		halo.set("_cast_elapsed", elapsed)
		checks["due_at_%d" % elapsed] = int(halo.call("_rocks_due")) == int(wanted[elapsed])  # dynamic: a private rule of the node, read by the case
	halo.set("_armed", true)
	checks["armed_all_six"] = int(halo.call("_rocks_due")) == 6
	halo.free()
	return _verdict("chain_halo_rocks", checks)


## Halo of Earth through the book: 6 rocks, they come out as the casting goes, they look for targets only when it ends, each of the 6 foes
## within 50 m takes one rock of 600 and the far one nothing; a second cast is refused while the halo lives.
func _halo() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "james", 5)
	var foes: Array[UnitBody] = []
	for i in 6:
		var angle := TAU * float(i) / 6.0
		foes.append(_unit(Vector3(20.0 * cos(angle), 0.0, 20.0 * sin(angle)), 3))
	var far := _unit(Vector3(0.0, 0.0, 110.0), 3)
	await _land(wizard)
	for body: UnitBody in foes + [far]:
		_full(body.get_node("Health"), 10000.0)
	var hurts := _watch(foes + [far])
	var caster := wizard.get_node("Caster") as Caster
	_mana(wizard)
	checks["in_book"] = caster.spellbook.index_of("olah") >= 0
	checks["arm_ok"] = caster.arm_status(caster.spellbook.index_of("olah")).is_empty()
	caster.request_cast("olah", ORIGIN, null)
	var halo := _first(_shots, HaloOfEarth) as HaloOfEarth
	checks["halo_made_at_start"] = halo != null and caster.is_casting()
	var cast_ticks := int(halo.get("_cast_ticks")) if halo != null else 1
	var coming_out := true
	var none_chase := true
	var guard := 0
	while caster.is_casting() and guard < 4000 and halo != null:
		await _frames(1)
		guard += 1
		var elapsed := int(halo.get("_cast_elapsed"))
		if elapsed > 0 and not bool(halo.get("_armed")):
			var due := mini(6, floori((float(elapsed - 1) / float(cast_ticks) + 0.1) * 6.0))
			coming_out = coming_out and int(halo.get("_spawned")) == due
		for rock in halo.get("_active"):
			none_chase = none_chase and rock.target == null
	checks["rocks_come_out_staggered"] = coming_out
	checks["no_rock_chases_while_casting"] = none_chase
	await _frames(3)
	checks["six_rocks_out"] = halo != null and int(halo.get("_spawned")) == 6
	checks["armed_after_casting"] = halo != null and bool(halo.get("_armed"))
	var again := caster.action_for("olah").check(wizard, GameData.spell("olah"), ORIGIN, null, "")
	checks["second_halo_refused"] = again.status == SpellAction.BAD_TARGET
	for _frame in 8000:
		await _frames(1)
		if halo == null or not is_instance_valid(halo):
			break
	var resistance := (foes[0].get_node("Health") as Health).resistance(Health.DIRECT_SPELL)
	var each_hit := true
	var total := 0.0
	for foe in foes:
		var took := _taken(hurts, foe)
		total += took
		each_hit = each_hit and absf(took - 600.0 * resistance) <= maxf(0.5, 600.0 * resistance * TOLERANCE)
	checks["each_foe_takes_one_rock_of_600"] = each_hit
	checks["total_is_six_rocks"] = absf(total - 3600.0 * resistance) <= maxf(1.0, 3600.0 * resistance * TOLERANCE)
	checks["far_untouched"] = _taken(hurts, far) == 0.0
	checks["halo_gone"] = halo == null or not is_instance_valid(halo)
	for node: Node in foes + [wizard, far]:
		node.queue_free()
	return _verdict("chain_halo", checks)


## A cast cut in the middle: the rocks that are out blow up where they are and the halo goes.
func _halo_abort() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "james", 5)
	await _land(wizard)
	var caster := wizard.get_node("Caster") as Caster
	_mana(wizard)
	caster.request_cast("olah", ORIGIN, null)
	var halo := _first(_shots, HaloOfEarth) as HaloOfEarth
	var cast_ticks := int(halo.get("_cast_ticks")) if halo != null else 1
	await _frames(int(cast_ticks * 0.6))
	checks["some_rocks_out"] = halo != null and int(halo.get("_spawned")) in range(1, 6)
	wizard.get_node("Health").damage(99999.0, 3)
	await _frames(MatchClock.ticks_for(0.5))
	checks["cut_by_death"] = not caster.is_casting()
	checks["halo_gone"] = halo == null or not is_instance_valid(halo) or halo.is_queued_for_deletion()
	checks["no_rock_left"] = _shots.get_child_count() == 0
	wizard.queue_free()
	return _verdict("chain_halo_abort", checks)


## The dragon burns what its box crosses: 175 per second, ignoring shields, nothing to the wizard or to a body outside its box.
func _dragon_burn() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "pyro", 5)
	var foe := _unit(Vector3(30.0, 0.0, 0.0), 3)
	var outside := _unit(Vector3(30.0, 0.0, 8.0), 3)
	await _land(wizard)
	_full(foe.get_node("Health"), 10000.0)
	_full(outside.get_node("Health"), 10000.0)
	var carrier := _make_carrier(wizard, foe)
	await _frames(2)
	carrier.global_position = BodyNudge.center(foe)
	var arrive := carrier.on_arrive as DragonArrive
	var resistance := (foe.get_node("Health") as Health).resistance(Health.DIRECT_SPELL)
	for _tick in MatchClock.TICKS_PER_SECOND:
		arrive.along(carrier)
	var took := 10000.0 - (foe.get_node("Health") as Health).current
	checks["burn_175_per_second"] = absf(took - 175.0 * resistance) <= 175.0 * resistance * 0.02
	checks["outside_box_untouched"] = (outside.get_node("Health") as Health).current == 10000.0
	var wizard_health := wizard.get_node("Health") as Health
	carrier.global_position = BodyNudge.center(wizard)
	arrive.along(carrier)
	checks["wizard_not_burned"] = wizard_health.current == wizard_health.maximum
	for node: Node in [carrier, wizard, foe, outside]:
		node.queue_free()
	return _verdict("chain_dragon_burn", checks)


## Dragonfire through the book: 6 foes 8 m apart, 5 hit (700 with a 5 m splash), flies at 18 m/s, and goes away when it has no more.
func _dragon() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "pyro", 5)
	var foes: Array[UnitBody] = []
	for i in 6:
		foes.append(_unit(Vector3(30.0 + 8.0 * i, 0.0, 0.0), 3))
	await _land(wizard)
	for foe in foes:
		_full(foe.get_node("Health"), 10000.0)
	var hurts := _watch(foes)
	var caster := wizard.get_node("Caster") as Caster
	_mana(wizard)
	checks["in_book"] = caster.spellbook.index_of("rifd") >= 0
	caster.request_cast("rifd", foes[0].global_position, foes[0])
	var carrier := _first(_spells, SpellCarrier) as SpellCarrier
	checks["dragon_made_at_start"] = carrier != null and carrier.phase == SpellCarrier.Phase.CASTING
	var arrive := carrier.on_arrive as DragonArrive if carrier != null else null
	var steps: Array[float] = []
	var last := carrier.global_position if carrier != null else ORIGIN
	var grew := true
	var cast_frames := 0
	while caster.is_casting() and cast_frames < 4000 and carrier != null:
		await _frames(1)
		cast_frames += 1
		grew = grew and carrier.scale.x > 0.0 and carrier.scale.x <= 1.0001
	checks["grows_while_casting"] = grew and cast_frames > 0
	await _frames(2)
	checks["flying_after_casting"] = carrier != null and carrier.phase == SpellCarrier.Phase.FLYING
	last = carrier.global_position if carrier != null else ORIGIN
	var guard := 0
	var hit_count := 0
	while carrier != null and is_instance_valid(carrier) and carrier.phase == SpellCarrier.Phase.FLYING and guard < 30000:
		await _frames(1)
		guard += 1
		if not is_instance_valid(carrier):
			break
		if steps.size() < 30:
			steps.append(carrier.global_position.distance_to(last))
		last = carrier.global_position
		hit_count = arrive.chain.hit_count()
	var speed := 0.0
	for step in steps:
		speed += step
	speed = speed / float(maxi(1, steps.size())) * MatchClock.TICKS_PER_SECOND_F
	checks["flies_at_18_m_s"] = absf(speed - 18.0) <= 18.0 * 0.02
	var late := 0
	while carrier != null and is_instance_valid(carrier) and late < 6000:
		await _frames(1)
		late += 1
	checks["five_targets_then_gone"] = carrier == null or not is_instance_valid(carrier)
	var resistance := (foes[0].get_node("Health") as Health).resistance(Health.SPLASH_SPELL)
	var hurt := 0
	for foe in foes:
		for event: Array in hurts[foe]:
			if event[1] == Health.SPLASH_SPELL and float(event[0]) >= 700.0 * resistance * 0.85:
				hurt += 1
	checks["five_hurt_by_700"] = hurt == 5
	checks["chain_counted_five"] = hit_count == 5
	for node: Node in foes + [wizard]:
		node.queue_free()
	return _verdict("chain_dragon", checks)


## With a single foe the dragon looks twice, finds nobody, and shrinks to nothing in a second.
func _dragon_alone() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, ORIGIN, "pyro", 5)
	var foe := _unit(Vector3(30.0, 0.0, 0.0), 3)
	await _land(wizard)
	_full(foe.get_node("Health"), 10000.0)
	var caster := wizard.get_node("Caster") as Caster
	_mana(wizard)
	caster.request_cast("rifd", foe.global_position, foe)
	var carrier := _first(_spells, SpellCarrier) as SpellCarrier
	var shrink_from := -1
	var gone := -1
	for tick in 40000:
		await _frames(1)
		if carrier == null or not is_instance_valid(carrier):
			gone = tick
			break
		if shrink_from < 0 and carrier.phase == SpellCarrier.Phase.SHRINKING:
			shrink_from = tick
	checks["shrinks_and_goes"] = shrink_from >= 0 and gone >= 0
	checks["shrink_takes_one_second"] = shrink_from >= 0 and gone >= 0 and absi((gone - shrink_from) - MatchClock.TICKS_PER_SECOND) <= 3
	wizard.queue_free()
	foe.queue_free()
	return _verdict("chain_dragon_alone", checks)


## The AI reads the four spells as it reads the rest of its book: a rating function is chosen, and with a foe (or an ally) in range the
## action says it could start.
func _ai() -> Dictionary:
	var checks := {}
	var foe := _unit(Vector3(-370.0, 0.0, -400.0), 3)
	var ally := _unit(Vector3(-390.0, 0.0, -400.0), 2)
	var casters: Dictionary = {}
	for pair in [["ntlc", "stratos"], ["wobr", "persephone"], ["rifd", "pyro"], ["olah", "james"]]:
		var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0 - 30.0 * casters.size()), pair[1], 5)
		casters[pair[0]] = wizard
	await _frames(3)
	for tag: String in casters:
		_mana(casters[tag])
		checks[tag + "_has_rating_fn"] = AiSpellEval.rating_fn(GameData.spell(tag)) != AiSpellEval.FN_NONE
	var ntlc := (casters["ntlc"].get_node("Caster") as Caster)
	var wobr := (casters["wobr"].get_node("Caster") as Caster)
	var rifd := (casters["rifd"].get_node("Caster") as Caster)
	var olah := (casters["olah"].get_node("Caster") as Caster)
	checks["ntlc_could_start_on_foe"] = ntlc.action_status("ntlc", foe.global_position, foe).is_empty()
	checks["rifd_could_start_on_foe"] = rifd.action_status("rifd", foe.global_position, foe).is_empty()
	checks["wobr_could_start_on_ally"] = wobr.action_status("wobr", ally.global_position, ally).is_empty()
	checks["olah_could_start_on_self"] = olah.action_status("olah", casters["olah"].global_position, casters["olah"]).is_empty()
	checks["wobr_refuses_a_foe"] = wobr.action_status("wobr", foe.global_position, foe) == SpellAction.BAD_TARGET
	checks["ntlc_refuses_an_ally"] = ntlc.action_status("ntlc", ally.global_position, ally) == SpellAction.BAD_TARGET
	checks["old_spells_unchanged"] = AiSpellEval.rating_fn(GameData.spell("ntil")) == AiSpellEval.FN_SINGLE and AiSpellEval.rating_fn(GameData.spell("laeh")) == AiSpellEval.FN_HEAL
	for node: Node in [foe, ally] + casters.values():
		node.queue_free()
	return _verdict("chain_ai", checks)


## The dragon of the book without casting: a SpellCarrier made as CarrierAction makes it, held in CASTING until the case moves it.
func _make_carrier(wizard: WizardBody, target: Node3D) -> SpellCarrier:
	var spawner := _spells.get_parent().get_node("SpellSpawner") as SpellSpawner
	var spell := GameData.spell("rifd")
	var data := LaunchPoint.projectile_data(wizard, spell, wizard.global_position, target, target.global_position)
	data["damage_range"] = spell.damage_range_m
	var carrier := spawner.spawn_projectile("Dragonfire", data) as SpellCarrier
	carrier.begin(wizard, spell, target, target.global_position, 10)
	return carrier


func _container(label: String, spawner: MultiplayerSpawner, spawner_name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	_root.add_child(holder)
	spawner.name = spawner_name
	spawner.spawn_path = NodePath("../" + label)
	_root.add_child(spawner)
	return holder


## A log of the hits each body takes: body -> [[amount, kind], ...]. Regeneration does not show, so a case reads the hits, not the health.
func _watch(bodies: Array) -> Dictionary:
	var log := {}
	for body: Node in bodies:
		log[body] = []
		(body.get_node("Health") as Health).hurt.connect(func(amount: float, kind: StringName, _slot: int) -> void:
			if amount > 0.0:
				(log[body] as Array).append([amount, kind]))
	return log


func _taken(log: Dictionary, body: Node) -> float:
	var total := 0.0
	for event: Array in log[body]:
		total += float(event[0])
	return total


## Mana to spare (the pool's maximum is the wizard's own).
func _mana(wizard: Node) -> void:
	var pool := wizard.get_node("ManaPool") as ManaPool
	pool.maximum = 10000.0
	pool.current = 5000.0


func _same(found: Array, expected: Array) -> bool:
	if found.size() != expected.size():
		return false
	for i in found.size():
		if found[i] != expected[i]:
			return false
	return true


func _first(holder: Node, type: Variant) -> Node:
	for child in holder.get_children():
		if is_instance_of(child, type):
			return child
	return null


func _full(health: Health, amount: float) -> void:
	health.maximum = amount
	health.current = amount


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
	unit.type = GameData.creature("nmuh")
	unit.model = type.model_id() if type else ""
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
			print("chain_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
