extends RefCounted

## RFC-061i cases of rules_suite: the five level-8 spells on one target (Charm mrhc, Blind Rage egar, Intestinal Vaporization pavi, Bovine
## Intervention ivob, Death taed) through CarrierAction, SpellCarrier and its children: who each may aim at, how long each takes, what it does to
## the target and to the others around, and the lights. Times are physics frames (the suite runs at any fixed fps), turned into seconds with
## `Engine.physics_ticks_per_second`. No network: the server paths run as solo. `run(host)` adds its own world and removes it.

const WORLD := preload("res://debug/suite/soul_world.gd")
const ORIGIN := Vector3(0.0, 0.0, 0.0)
## The tolerance of a time, in frames.
const SLACK := 4

var _w := WORLD.new()
var _fps := 60


func run(host: Node3D) -> Dictionary:
	_fps = Engine.physics_ticks_per_second
	_w.build(host, "Level8Cases")
	var shots := Node3D.new()
	shots.name = "Shots"
	_w.root.add_child(shots)
	var shot_spawner := ShotSpawner.new()
	shot_spawner.name = "ShotSpawner"
	shot_spawner.spawn_path = NodePath("../Shots")
	_w.root.add_child(shot_spawner)
	var out := {}
	out["level8_data"] = _data()
	out["level8_targets"] = await _targets()
	out["level8_lights"] = _lights()
	out["level8_vaporization"] = await _vaporization()
	out["level8_charm"] = await _charm()
	out["level8_rage"] = await _rage()
	out["level8_cow"] = await _cow()
	out["level8_death_speed"] = await _death_speed()
	out["level8_death"] = await _death()
	out["level8_death_time"] = await _death_time()
	out["level8_ai"] = _ai()
	_w.clear()
	return out


## The five spells have their action scene (a CarrierAction without warnings), are in their god's book at level 9 and the AI rates them like the original flags did.
func _data() -> Dictionary:
	var checks := {}
	checks["death_counts_eight"] = GameData.spell("taed").max_targets == 8
	checks["death_duration_is_forty"] = is_equal_approx(GameData.spell("taed").duration_s, 40.0)
	var fn_of := {"mrhc": AiSpellEval.FN_NONE, "egar": AiSpellEval.FN_AREA, "pavi": AiSpellEval.FN_SINGLE, "ivob": AiSpellEval.FN_SINGLE, "taed": AiSpellEval.FN_NONE}
	for pair in [["mrhc", "persephone"], ["egar", "pyro"], ["pavi", "charnel"], ["ivob", "james"], ["taed", "charnel"]]:
		var tag: String = pair[0]
		var spell := GameData.spell(tag)
		var action := spell.action.instantiate() as SpellAction if spell != null and spell.action != null else null
		checks[tag + "_action_scene"] = action is CarrierAction
		if action != null:
			action.tag = tag
			checks[tag + "_no_warnings"] = action._get_configuration_warnings().is_empty()
			var carrier_action := action as CarrierAction
			checks[tag + "_kind_in_spawner"] = carrier_action != null and SpellSpawner.new().projectiles.has(carrier_action.kind)
			action.free()
		var tags: Array = []
		for entry in GameData.book(pair[1], 9)["spells"]:
			tags.append(entry.tag)
		checks[tag + "_in_book"] = tags.has(tag)
		checks[tag + "_evaluator"] = AiSpellEval.rating_fn(spell) == fn_of[tag]
	return _w.verdict("level8_data", checks)


## Who each spell may aim at: creatures that are not allies and not wizards; Charm also not a creature of no player; Death anybody.
func _targets() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "charnel", 9)
	var foe := _w.unit(Vector3(0.0, 0.0, 30.0), 3)
	var ally := _w.unit(Vector3(5.0, 0.0, 30.0), 2)
	var neutral := _w.unit(Vector3(10.0, 0.0, 30.0), 0)
	var rival := _w.wizard(3, Vector3(15.0, 0.0, 30.0), "pyro", 9)
	await _w.frames(3)
	for tag in ["mrhc", "egar", "pavi", "ivob"]:
		var target := _target_of(tag)
		checks[tag + "_takes_a_foe"] = target.pick(wizard, foe) == foe
		checks[tag + "_refuses_an_ally"] = target.pick(wizard, ally) == null
		checks[tag + "_refuses_a_wizard"] = target.pick(wizard, rival) == null
		checks[tag + "_nothing_picked"] = target.pick(wizard, null) == null
	checks["charm_refuses_a_creature_of_no_player"] = _target_of("mrhc").pick(wizard, neutral) == null
	checks["rage_takes_a_creature_of_no_player"] = _target_of("egar").pick(wizard, neutral) == neutral
	var death := _target_of("taed")
	checks["death_takes_an_ally"] = death.pick(wizard, ally) == ally
	checks["death_takes_a_wizard"] = death.pick(wizard, rival) == rival
	var action := GameData.spell("taed").action.instantiate() as CarrierAction
	checks["death_takes_the_ground"] = action.ground_ok and action.spawn_at == CarrierAction.Where.AIM
	action.free()
	var cow := GameData.spell("ivob").action.instantiate() as CarrierAction
	checks["cow_is_born_when_the_cast_ends"] = cow.spawn_when == CarrierAction.When.FINISH and is_equal_approx(cow.ahead_m, 15.0) and is_equal_approx(cow.depth_m, 4.0)
	cow.free()
	for node: Node in [wizard, foe, ally, neutral, rival]:
		node.queue_free()
	return _w.verdict("level8_targets", checks)


## The light of every carrier is the dominant color of its texture (061V-i) and the bursts have their own.
func _lights() -> Dictionary:
	var checks := {}
	var expected := {
		"charm": Color(1, 0.1, 0.3), "blind_rage": Color(1, 0.3, 0.2), "vaporization": Color(1, 0.5, 0.47),
		"bovine_intervention": Color(1, 0.8, 0.44), "death": Color(0.75, 0.05, 1),
	}
	for name: String in expected:
		var scene := load("res://scenes/spells/carrier/%s.tscn" % name) as PackedScene
		var carrier := scene.instantiate() as SpellCarrier
		var light := carrier.get_node_or_null("Glow") as StateLight
		checks[name + "_has_light"] = light != null and light.lit_on_ready
		if light != null:
			var color: Color = expected[name]
			checks[name + "_light_color"] = absf(light.light_color.r - color.r) < 0.02 and absf(light.light_color.g - color.g) < 0.02 and absf(light.light_color.b - color.b) < 0.02
			checks[name + "_light_no_shadow"] = not light.shadow_enabled
		carrier.free()
	for fx in ["charm_hearts", "rage_blast", "vaporize_burst", "cow_burst", "death_strike"]:
		var type := FxBus.particle_type(fx)
		checks[fx + "_has_light"] = type != null and type.light != null
	return _w.verdict("level8_lights", checks)


## Intestinal Vaporization: the shot arrives, the target is stunned and swells for 5 s, then bursts without a corpse and its soul stays.
func _vaporization() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "charnel", 9)
	var foe := _w.unit(Vector3(0.0, 0.0, 40.0), 3, 10000.0)
	await _land(wizard)
	var growth := DevourGrowth.of(foe)
	var stuns := [0]
	(foe.get_node("Afflictions/Stunned") as Stunned).shown_changed.connect(func(on: bool) -> void: stuns[0] += 1 if on else 0)
	(wizard.get_node("Caster") as Caster).request_cast("pavi", foe.global_position, foe)
	var carrier := _w.carrier()
	checks["carrier_made_at_the_start"] = carrier != null and carrier.phase == SpellCarrier.Phase.CASTING
	var swell := 0.0
	var arrived := await _w.until(func() -> bool: return _phase() == SpellCarrier.Phase.HOLDING, 12 * _fps)
	checks["shot_arrives"] = arrived >= 0
	var started := Engine.get_physics_frames()
	var at := foe.global_position
	var soul_count := GameData.creature("nmuh").souls
	var gone := -1
	for tick in 8 * _fps:
		await _w.frames(1)
		if growth != null and is_instance_valid(foe):
			swell = maxf(swell, growth.inflation)
		if not is_instance_valid(foe) or foe.is_queued_for_deletion():
			gone = Engine.get_physics_frames() - started
			break
	checks["bursts_after_five_seconds"] = gone > 0 and absi(gone - 5 * _fps) <= SLACK
	checks["swelled_to_the_full"] = swell > 0.95
	checks["stunned_at_least_twice"] = stuns[0] >= 2
	await _w.frames(4)
	var soul: Soul = null
	for node in _w.host.get_tree().get_nodes_in_group("soul"):
		if (node as Node3D).global_position.distance_to(at) < 3.0:
			soul = node as Soul
	checks["soul_stays"] = soul != null and soul.number == soul_count and not soul.attached
	var corpses := 0
	for node in _w.host.get_tree().get_nodes_in_group("corpse"):
		corpses += 1 if (node as Node3D).global_position.distance_to(at) < 3.0 else 0
	checks["no_corpse"] = corpses == 0
	wizard.queue_free()
	return _w.verdict("level8_vaporization", checks)


## Charm: 5 s around the creature, then it is the wizard's for good, without orders and told to follow him; a creature that dies first stays.
func _charm() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "persephone", 9)
	var foe := _w.unit(Vector3(0.0, 0.0, 40.0), 3, 10000.0)
	var doomed := _w.unit(Vector3(12.0, 0.0, 40.0), 3, 10000.0)
	await _land(wizard)
	var caster := wizard.get_node("Caster") as Caster
	checks["wizard_not_charmable"] = caster.action_status("mrhc", ORIGIN, wizard) == SpellAction.BAD_TARGET
	caster.request_cast("mrhc", foe.global_position, foe)
	var carrier := _w.carrier()
	var arrived := await _w.until(func() -> bool: return _phase() == SpellCarrier.Phase.HOLDING, 12 * _fps)
	checks["spirits_arrive"] = arrived >= 0
	var started := Engine.get_physics_frames()
	checks["still_theirs_on_arriving"] = foe.owner_slot == 3
	var changed := await _w.until(func() -> bool: return foe.owner_slot == 1, 8 * _fps)
	checks["changes_side_after_five_seconds"] = changed >= 0 and absi((Engine.get_physics_frames() - started) - 5 * _fps) <= SLACK
	var orders = foe.get_node("Orders")
	checks["told_to_follow_the_wizard"] = int(orders.get("command")) == 6 and orders.get("target") == wizard
	checks["target_forgotten"] = foe.target == null
	checks["it_is_for_good"] = await _still(func() -> bool: return foe.owner_slot == 1, 2 * _fps)
	checks["spirits_stay_ten_seconds"] = carrier != null and is_instance_valid(carrier) and carrier.phase == SpellCarrier.Phase.LINGERING
	caster.request_cast("mrhc", doomed.global_position, doomed)
	var second := await _w.until(func() -> bool: return _holding(), 12 * _fps)
	if second >= 0:
		(doomed.get_node("Health") as Health).damage(99999.0, 1)
	await _w.frames(7 * _fps)
	checks["dead_creature_is_not_turned"] = doomed.owner_slot == 3
	for node: Node in [wizard, foe, doomed]:
		node.queue_free()
	return _w.verdict("level8_charm", checks)


## Blind Rage: 30 s of fury for every creature (not wizards, shields or no) within 30 m of the fist; no orders; any side is a foe.
func _rage() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "pyro", 9)
	var aim := _w.unit(Vector3(0.0, 0.0, 40.0), 3, 10000.0)
	var near_foe := _w.unit(Vector3(10.0, 0.0, 40.0), 3, 10000.0)
	var near_ally := _w.unit(Vector3(-10.0, 0.0, 40.0), 2, 10000.0)
	var far_edge := _w.unit(Vector3(0.0, 0.0, 68.0), 3, 10000.0)
	var too_far := _w.unit(Vector3(0.0, 0.0, 75.0), 3, 10000.0)
	var rival := _w.wizard(3, Vector3(5.0, 0.0, 45.0), "stratos", 9)
	await _land(wizard)
	var shielded := near_foe.get_node_or_null("Wards/LifeShield")
	if shielded != null:
		shielded.call("start_for", GameData.ability("kdbs"))
	var caster := wizard.get_node("Caster") as Caster
	caster.request_cast("egar", aim.global_position, aim)
	var carrier := _w.carrier()
	var arrived := await _w.until(func() -> bool: return _phase() == SpellCarrier.Phase.HOLDING, 12 * _fps)
	checks["fist_arrives"] = arrived >= 0
	var hold_start := Engine.get_physics_frames()
	var raged := await _w.until(func() -> bool: return _raging(aim), 4 * _fps)
	checks["blast_82_ticks_after_arriving"] = raged >= 0 and absi((Engine.get_physics_frames() - hold_start) - roundi(82.0 / 60.0 * _fps)) <= SLACK
	var started := Engine.get_physics_frames()
	for body: Node in [aim, near_foe, near_ally, far_edge]:
		checks[str(body.name) + "_enraged"] = _raging(body)
	checks["beyond_30_m_is_calm"] = not _raging(too_far)
	checks["wizards_are_calm"] = not _raging(rival)
	var orders = near_ally.get_node("Orders")
	orders.call("give", 1, near_foe, near_foe.global_position, Vector2.ZERO, 0.0)
	checks["no_order_is_taken"] = int(orders.get("command")) == 0
	var picker := near_ally.get_node("TargetPicker") as TargetPicker
	checks["picks_by_the_rage_rule"] = picker.active() == picker.rage_policy and picker.rage_policy != null
	var chosen := near_ally.engagement.closest_foe(near_ally.global_position)
	checks["fights_the_closest_creature"] = chosen != null and chosen != near_ally
	checks["own_side_is_a_foe"] = near_ally.engagement.accepts_target(aim) and picker.accepts(near_foe, true)
	var calm := await _w.until(func() -> bool: return not _raging(aim), 31 * _fps)
	checks["fury_lasts_thirty_seconds"] = calm >= 0 and absi((Engine.get_physics_frames() - started) - 30 * _fps) <= SLACK
	orders.call("give", 1, near_foe, near_foe.global_position, Vector2.ZERO, 0.0)
	checks["obeys_again"] = int(orders.get("command")) == 1
	for node: Node in [wizard, aim, near_foe, near_ally, far_edge, too_far, rival]:
		node.queue_free()
	return _w.verdict("level8_rage", checks)


## Bovine Intervention: born buried 15 m ahead when the cast ends, 12 s onto the target on an arc 200 m high, gibs it (soul stays), and when it goes through
## the land its wave stuns up to 25 m and hurts nobody.
func _cow() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "james", 9)
	var foe := _w.unit(Vector3(0.0, 0.0, 40.0), 3, 10000.0)
	var near := _w.unit(Vector3(0.0, 0.0, 52.0), 3, 10000.0)
	var far := _w.unit(Vector3(0.0, 0.0, 66.0), 3, 10000.0)
	await _land(wizard)
	var at := foe.global_position
	(wizard.get_node("Caster") as Caster).request_cast("ivob", at, foe)
	checks["not_born_while_casting"] = _w.carrier() == null
	var born := await _w.until(func() -> bool: return _w.carrier() != null, 12 * _fps)
	var carrier := _w.carrier()
	checks["born_when_the_cast_ends"] = born >= 0 and carrier != null
	var started := Engine.get_physics_frames()
	var start := carrier.global_position if carrier != null else ORIGIN
	checks["born_fifteen_metres_ahead"] = start.distance_to(Vector3(0.0, -4.0, 15.0)) < 0.5
	await _w.frames(6 * _fps)
	var goal_y := BodyNudge.center(foe).y if is_instance_valid(foe) else 0.9
	var expected := (goal_y + start.y) / 2.0 + 200.0
	checks["half_way_up_at_200_m"] = carrier != null and is_instance_valid(carrier) and absf(carrier.global_position.y - expected) < 2.0
	var health_far := (far.get_node("Health") as Health).current
	var stunned := {"near": false, "far": false}
	var gone := -1
	for tick in 8 * _fps:
		await _w.frames(1)
		stunned["near"] = stunned["near"] or _w.stunned(near)
		stunned["far"] = stunned["far"] or _w.stunned(far)
		if gone < 0 and (not is_instance_valid(foe) or foe.is_queued_for_deletion()):
			gone = Engine.get_physics_frames() - started
	checks["gibs_the_target_after_twelve_seconds"] = gone > 0 and absi(gone - 12 * _fps) <= SLACK
	for tick in roundi(0.8 * _fps):
		await _w.frames(1)
		stunned["near"] = stunned["near"] or _w.stunned(near)
		stunned["far"] = stunned["far"] or _w.stunned(far)
	checks["stuns_at_12_m"] = stunned["near"]
	checks["does_not_stun_at_26_m"] = not stunned["far"]
	checks["hurts_nobody"] = (far.get_node("Health") as Health).current >= health_far and (near.get_node("Health") as Health).current >= (near.get_node("Health") as Health).maximum - 1.0
	var soul_found := false
	for node in _w.host.get_tree().get_nodes_in_group("soul"):
		soul_found = soul_found or (node as Node3D).global_position.distance_to(at) < 3.0
	checks["soul_stays"] = soul_found
	checks["cow_gone_after_landing"] = _w.carrier() == null
	for node: Node in [wizard, near, far]:
		node.queue_free()
	return _w.verdict("level8_cow", checks)


## Death walks at 18 m/s.
func _death_speed() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "charnel", 9)
	var prey := _w.unit(Vector3(0.0, 0.0, 190.0), 3, 10000.0)
	await _land(wizard)
	var caster := wizard.get_node("Caster") as Caster
	caster.request_cast("taed", Vector3(0.0, 0.0, 50.0), null)
	var carrier := _w.carrier()
	checks["born_at_the_click"] = carrier != null and carrier.global_position.distance_to(Vector3(0.0, 0.0, 50.0)) < 0.5
	checks["stands_while_casting"] = carrier != null and carrier.phase == SpellCarrier.Phase.CASTING
	await _w.until(func() -> bool: return _phase() == SpellCarrier.Phase.FLYING, 12 * _fps)
	await _w.frames(_fps / 2)
	var from := carrier.global_position
	await _w.frames(_fps)
	var speed := (carrier.global_position - from).length()
	checks["walks_at_18_m_s"] = absf(speed - 18.0) <= 18.0 * 0.03
	carrier.stop()
	for node: Node in [wizard, prey]:
		node.queue_free()
	return _w.verdict("level8_death_speed", checks)


## Death with ten creatures: it kills the closest of any side that is not a wizard (its own wizard's creature first), eight of them, and leaves.
func _death() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "charnel", 9)
	var rival := _w.wizard(3, Vector3(0.0, 0.0, 36.0), "pyro", 9)
	var own := _w.unit(Vector3(3.0, 0.0, 44.0), 1, 10000.0)
	var prey: Array[UnitBody] = [own]
	for i in 9:
		prey.append(_w.unit(Vector3(-24.0 + 6.0 * i, 0.0, 52.0 + 2.0 * (i % 3)), 3, 10000.0))
	await _land(wizard)
	(wizard.get_node("Caster") as Caster).request_cast("taed", Vector3(0.0, 0.0, 40.0), null)
	var carrier := _w.carrier()
	await _w.until(func() -> bool: return _armed(), 12 * _fps)
	var gone := await _w.until(func() -> bool: return _w.carrier() == null, 30 * _fps)
	checks["leaves"] = gone >= 0
	var dead := 0
	for body in prey:
		dead += 1 if is_instance_valid(body) and (body.get_node("Health") as Health).is_dead() else 0
	checks["kills_eight"] = dead == 8
	checks["its_own_side_first"] = (own.get_node("Health") as Health).is_dead()
	checks["never_a_wizard"] = not (rival.get_node("Health") as Health).is_dead()
	var corpses := _w.host.get_tree().get_nodes_in_group("corpse").size()
	checks["corpses_stay"] = corpses >= 8
	for node: Node in prey + [wizard, rival]:
		node.queue_free()
	return _w.verdict("level8_death", checks)


## Death with one creature: it kills it and then stays until the 40 s are over, and leaves.
func _death_time() -> Dictionary:
	var checks := {}
	var wizard := _w.wizard(1, ORIGIN, "charnel", 9)
	var prey := _w.unit(Vector3(0.0, 0.0, 44.0), 3, 10000.0)
	await _land(wizard)
	(wizard.get_node("Caster") as Caster).request_cast("taed", Vector3(0.0, 0.0, 40.0), null)
	var carrier := _w.carrier()
	await _w.until(func() -> bool: return _armed(), 12 * _fps)
	var started := Engine.get_physics_frames()
	var gone := await _w.until(func() -> bool: return _w.carrier() == null, 45 * _fps)
	var lasted := Engine.get_physics_frames() - started
	checks["kills_the_only_creature"] = (prey.get_node("Health") as Health).is_dead()
	checks["stays_forty_seconds_at_least"] = gone >= 0 and lasted >= 40 * _fps - SLACK
	checks["leaves_within_a_walk_cycle_and_the_exit"] = gone >= 0 and lasted <= roundi(42.3 * _fps)
	for node: Node in [wizard, prey]:
		node.queue_free()
	return _w.verdict("level8_death_time", checks)


## The AI reads the five without breaking (Charm and Death have no evaluator).
func _ai() -> Dictionary:
	var checks := {}
	for tag in ["mrhc", "egar", "pavi", "ivob", "taed"]:
		checks[tag + "_rates_without_error"] = AiSpellEval.rating_fn(GameData.spell(tag)) >= AiSpellEval.FN_NONE
	return _w.verdict("level8_ai", checks)


func _target_of(tag: String) -> SpellTarget:
	var action := GameData.spell(tag).action.instantiate() as CarrierAction
	var target := action.target
	action.free()
	return target


func _raging(body: Node) -> bool:
	var afflictions := Afflictions.of(body)
	return afflictions != null and afflictions.raging()


func _holding() -> bool:
	return _phase() == SpellCarrier.Phase.HOLDING


## The phase of the carrier the spawner made, -1 when there is none.
func _phase() -> int:
	var carrier := _w.carrier()
	return carrier.phase if carrier != null else -1


func _armed() -> bool:
	var carrier := _w.carrier()
	return carrier != null and carrier.armed


## True when `condition` stays true for `frames` frames.
func _still(condition: Callable, frames: int) -> bool:
	for _i in frames:
		await _w.frames(1)
		if not condition.call():
			return false
	return true


## The wizard falls from where he spawns: waits until he stands (at most 3 s).
func _land(wizard: WizardBody) -> void:
	for _i in 3 * _fps:
		await _w.frames(1)
		if wizard.is_on_floor():
			return
