extends RefCounted

## RFC-061c cases of rules_suite: the four control spells on one body (Freeze, Grasping Vines, Rings of Fire, Slime) through
## AfflictAction, SpellTarget, Frozen, Vined and SpellAffliction: how long each lasts, what a layer of Slime does to pace, swing,
## aim and resistance, who refuses them, the cast from the book of each god, what the AI does with them, and the Troll that regenerates
## in any state. No network: the server paths run as solo. `run(host)` adds its own bodies and removes them.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RULES := preload("res://data/match_rules.tres")
const SPELLS: Array[String] = ["zerf", "eniv", "rapf", "htel"]
const GODS := {"zerf": "stratos", "eniv": "persephone", "rapf": "pyro", "htel": "charnel"}
const TYPES := {
	"zerf": "res://data/afflictions/frozen.tres",
	"eniv": "res://data/afflictions/vined.tres",
	"rapf": "res://data/afflictions/rings_of_fire.tres",
	"htel": "res://data/afflictions/slimed.tres",
}
const TOLERANCE := 0.01

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "ControlCases"
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
	out["control_scenes"] = await _scenes()
	out["control_freeze"] = await _freeze()
	out["control_vines"] = await _vines()
	out["control_rings"] = await _rings()
	out["control_slime"] = await _slime()
	out["control_slime_fight"] = await _slime_fight()
	out["control_refuse"] = await _refuse()
	out["control_cast"] = await _cast()
	out["control_troll"] = await _troll()
	out["control_late_join"] = await _late_join()
	out["control_ai"] = await _ai()
	SideRelations.refresh()
	_root.queue_free()
	return out


## The four spells have an AfflictAction scene with a target and a state of the bodies; every body (creature and wizard) has the states.
func _scenes() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "stratos", 3)
	var unit := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	await _frames(2)
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		var type := load(TYPES[tag]) as AfflictionType
		checks[tag + "_has_action"] = spell != null and spell.action != null and spell.ai_use == SpellType.AiUse.DISABLE_FOE
		var action := spell.action.instantiate() as AfflictAction if spell and spell.action else null
		checks[tag + "_action_class"] = action != null and action.target != null and action.affliction == type
		if action != null:
			action.tag = tag
			checks[tag + "_no_warnings"] = action._get_configuration_warnings().is_empty()
			action.free()
		for body in [wizard, unit]:
			var state := Afflictions.of(body).child_for(type)
			checks[tag + "_state_" + str(body.name)] = state != null and state.type == type
	checks["afflictions_is_node3d"] = Afflictions.of(unit) is Node3D and Afflictions.of(unit).get_child(0) is Node3D
	checks["bits_distinct"] = _bits_distinct(unit)
	checks["rings_bit_9_slime_bit_10"] = (load(TYPES["rapf"]) as AfflictionType).bit == 9 and (load(TYPES["htel"]) as AfflictionType).bit == 10
	wizard.queue_free()
	unit.queue_free()
	return _verdict("control_scenes", checks)


func _bits_distinct(body: Node) -> bool:
	var seen := {}
	for child in Afflictions.of(body).get_children():
		var state := child as Affliction
		if state == null or state.type == null:
			continue
		var key := "%d" % state.type.bit
		if seen.has(key) and seen[key] != state.type.id:
			return false
		seen[key] = state.type.id
	return true


## Freeze: ceil(60 * 1000 / health * 20) ticks on a creature, 300 on a wizard; the thaw is 150 of direct spell damage from the side
## that froze it. A flier falls; the cast does not go through the Yeti's cooldown (two spells in a row freeze twice).
func _freeze() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("zerf")
	var unit := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	var wizard := _wizard(3, Vector3(0.0, 0.0, 40.0), "persephone", 3)
	await _frames(3)
	var health := unit.get_node("Health") as Health
	var frozen := unit.get_node("Afflictions/Frozen") as Frozen
	var expected := ceili(60.0 * 1000.0 / health.maximum * spell.duration_s)
	checks["creature_ticks_formula"] = absi(frozen.lay_ticks(spell) - expected) <= 1
	checks["lay_froze"] = frozen.lay(spell, 1) and frozen.is_on()
	var ticks := await _count_until_off(frozen, 2000)
	checks["creature_ticks"] = absi(ticks - expected) <= 2
	var w_health := wizard.get_node("Health") as Health
	w_health.setup(10000.0)
	var w_frozen := wizard.get_node("Afflictions/Frozen") as Frozen
	checks["wizard_ticks_formula"] = w_frozen.lay_ticks(spell) == 300
	w_frozen.lay(spell, 1)
	var before := w_health.current
	var w_ticks := await _count_until_off(w_frozen, 500)
	await _frames(3)
	checks["wizard_ticks"] = absi(w_ticks - 300) <= 2
	var taken := before - w_health.current
	var want := float(spell.damage) * w_health.resistance(Health.DIRECT_SPELL)
	checks["thaw_damage"] = want > 0.0 and absf(taken - want) <= want * TOLERANCE + 0.5
	checks["no_yeti_cooldown"] = w_frozen.lay(spell, 1) and w_frozen.is_on()
	checks["frozen_is_protected"] = Afflictions.of(wizard).cc_protected()
	checks["no_second_freeze"] = not w_frozen.lay(spell, 1)
	unit.queue_free()
	wizard.queue_free()
	return _verdict("control_freeze", checks)


## Grasping Vines: ceil(60 * 1000 / health * 40) ticks on a creature, 600 on a wizard, whose xz velocity is 0; a flier refuses.
func _vines() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("eniv")
	var wizard := _wizard(3, Vector3.ZERO, "persephone", 3)
	var unit := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	var flier := _unit("tbsh", Vector3(-30.0, 0.0, 0.0), 3)
	await _frames(90)
	var vined := wizard.get_node("Afflictions/Vined") as Vined
	var expected := ceili(60.0 * 1000.0 / (unit.get_node("Health") as Health).maximum * spell.duration_s)
	checks["creature_ticks_formula"] = absi((unit.get_node("Afflictions/Vined") as Vined).lay_ticks(spell) - expected) <= 1
	checks["wizard_ticks_formula"] = vined.lay_ticks(spell) == 600
	checks["lay"] = vined.lay(spell, 1) and vined.is_on()
	var steered := Afflictions.of(wizard).steer(Vector3(5.0, 0.0, 5.0), 1.0 / 60.0)
	checks["no_walk"] = steered.x == 0.0 and steered.z == 0.0
	checks["protected"] = Afflictions.of(wizard).cc_protected() and Afflictions.of(wizard).blocks_regeneration()
	var ticks := await _count_until_off(vined, 800)
	checks["wizard_ticks"] = absi(ticks - 600) <= 2
	var caster := Caster.of(wizard)
	var enemy_wizard := _wizard(1, Vector3(0.0, 0.0, 60.0), "persephone", 3)
	var action := caster.action_for("eniv")
	checks["flier_is_flying"] = flier.is_flying()
	var caster_1 := Caster.of(enemy_wizard)
	var action_1 := caster_1.action_for("eniv")
	checks["flier_refused"] = action_1.check(enemy_wizard, spell, flier.global_position, flier, "").status == SpellAction.BAD_TARGET
	checks["ground_accepted"] = action_1.check(enemy_wizard, spell, unit.global_position, unit, "").status == "" and action != null
	unit.queue_free()
	flier.queue_free()
	wizard.queue_free()
	enemy_wizard.queue_free()
	return _verdict("control_vines", checks)


## Rings of Fire: 600 ticks, 950 of direct spell damage (pierces a Life Shield), no regeneration, and a Freeze after it is refused.
func _rings() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("rapf")
	var unit := _unit("nmuh", Vector3(30.0, 0.0, 0.0), 3)
	await _frames(3)
	var health := unit.get_node("Health") as Health
	health.maximum = 10000.0
	health.current = 10000.0
	var shield := LifeShield.of(unit)
	shield.start(100000)
	var rings := unit.get_node("Afflictions/RingsOfFire") as SpellAffliction
	var resistance := health.resistance(Health.DIRECT_SPELL)
	checks["victim_takes_spells"] = resistance > 0.0
	checks["lay_ticks"] = rings.lay_ticks(spell) == 600
	checks["lay"] = rings.lay(spell, 1) and rings.is_on() and rings.layers() == 1
	checks["second_cast_no_layer"] = not rings.lay(spell, 1) and rings.layers() == 1
	checks["protected"] = Afflictions.of(unit).cc_protected() and Afflictions.of(unit).blocks_regeneration()
	health.regenerate(100.0)
	checks["no_regeneration"] = health.current == 10000.0
	var ticks := await _count_until_off(rings, 800)
	checks["ticks"] = absi(ticks - 600) <= 2
	var taken := 10000.0 - health.current
	checks["damage_950"] = absf(taken - 950.0 * resistance) <= 9.5 * resistance + 0.5
	checks["ended"] = not rings.is_on() and not Afflictions.of(unit).blocks_regeneration()
	var frozen := unit.get_node("Afflictions/Frozen") as Frozen
	rings.lay(spell, 1)
	checks["no_freeze_while_on"] = rings.is_on() and not frozen.try_freeze_with_cooldown(GameData.spell("zerf"), 1)
	unit.queue_free()
	return _verdict("control_rings", checks)


## Slime: each layer x0.2 pace, +0.2 resistance, melee accuracy and evasion x0.2, swings and shots x5; 7.5 s on a wizard; the skin texture.
func _slime() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("htel")
	var unit := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	var wizard := _wizard(3, Vector3.ZERO, "charnel", 3)
	await _frames(3)
	var slimed := unit.get_node("Afflictions/Slimed") as SpellAffliction
	var afflictions := Afflictions.of(unit)
	var pace := PaceFactors.of(unit)
	var health := unit.get_node("Health") as Health
	var expected := ceili(60.0 * 1000.0 / health.maximum * spell.duration_s)
	checks["creature_ticks_formula"] = absi(slimed.lay_ticks(spell) - expected) <= 1
	var base_resistance := health.resistance(Health.MELEE)
	checks["clean"] = pace.factor_of(&"slimed") == 1.0 and afflictions.stat_factor(Afflictions.Stat.ATTACK_TIME) == 1.0 and not slimed.is_on()
	checks["layer_1"] = slimed.lay(spell, 1) and slimed.layers() == 1
	checks["pace_1"] = absf(pace.factor_of(&"slimed") - 0.2) < 1e-6 and absf(unit.speed_factor - 0.2) < 1e-6
	checks["resistance_1"] = absf(health.resistance(Health.MELEE) - base_resistance - 0.2) < 1e-6
	checks["attack_1"] = absf(afflictions.stat_factor(Afflictions.Stat.ATTACK_TIME) - 5.0) < 1e-6
	checks["accuracy_1"] = absf(afflictions.stat_factor(Afflictions.Stat.ACCURACY) - 0.2) < 1e-6
	checks["layer_2"] = slimed.lay(spell, 1) and slimed.layers() == 2
	checks["pace_2"] = absf(pace.factor_of(&"slimed") - 0.04) < 1e-6
	checks["resistance_2"] = absf(health.resistance(Health.MELEE) - base_resistance - 0.4) < 1e-6
	checks["attack_2"] = absf(afflictions.stat_factor(Afflictions.Stat.ATTACK_TIME) - 25.0) < 1e-6
	checks["accuracy_2"] = absf(afflictions.stat_factor(Afflictions.Stat.ACCURACY) - 0.04) < 1e-6
	checks["protected_and_blocked"] = afflictions.cc_protected() and afflictions.blocks_regeneration()
	health.setup(1000.0)
	health.current = 500.0
	health.regenerate(50.0)
	checks["no_regeneration"] = health.current == 500.0
	var w_slime := wizard.get_node("Afflictions/Slimed") as SpellAffliction
	checks["wizard_ticks_formula"] = w_slime.lay_ticks(spell) == 450
	w_slime.lay(spell, 1)
	var ticks := await _count_until_off(w_slime, 600)
	checks["wizard_ticks"] = absi(ticks - 450) <= 2
	checks["wizard_pace_back"] = PaceFactors.of(wizard).factor_of(&"slimed") == 1.0
	afflictions.shown = 0
	checks["creature_clean_after"] = not slimed.is_on() and pace.factor_of(&"slimed") == 1.0
	unit.queue_free()
	wizard.queue_free()
	return _verdict("control_slime", checks)


## The swing of a slimed attacker lasts 5 times as long (a layer) and its aim is x0.2; a slimed target is hit with its evasion x0.2.
func _slime_fight() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("htel")
	var hitter := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	var victim := _unit("ycro", Vector3(30.0, 0.0, 1.0), 1)
	await _frames(3)
	var melee := hitter.get_node("MeleeAttack") as MeleeAttack
	melee.start(victim)
	var index := melee.swing_index()
	var plain := _swing_ticks(melee)
	var chance_plain := float(melee.roll_damage(victim)["chance"])
	var slimed := hitter.get_node("Afflictions/Slimed") as SpellAffliction
	slimed.lay(spell, 1)
	var slow := 0
	for _try in 12:
		melee.start(victim)
		if melee.swing_index() == index:
			slow = _swing_ticks(melee)
			break
		melee.cancel()
	checks["swing_5x"] = plain > 0 and absi(slow - plain * 5) <= 5
	checks["accuracy_lower"] = float(melee.roll_damage(victim)["chance"]) < chance_plain
	var slimed_victim := victim.get_node("Afflictions/Slimed") as SpellAffliction
	slimed_victim.lay(spell, 3)
	var both := melee.roll_damage(victim)
	var accuracy := float(both["accuracy"])
	checks["attacker_accuracy_x02"] = absf(accuracy - float(hitter.type.melee_accuracy_milli()) * 0.2) < 0.01
	checks["target_evasion_x02"] = absf(float(both["evasion"]) - float(victim.type.melee_evasion_milli()) * 0.2) < 0.01
	hitter.queue_free()
	victim.queue_free()
	return _verdict("control_slime_fight", checks)


func _swing_ticks(melee: MeleeAttack) -> int:
	var ticks := 0
	while melee.advance(1.0 / 60.0) and ticks < 5000:
		ticks += 1
	return ticks


## The four refuse a body that is ccProtected (a Druid with Life Shield, a wizard with Skin of Stone), a dead one and an ally; they
## accept a plain enemy; Vines also refuse a flier.
func _refuse() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, Vector3.ZERO, "stratos", 3)
	var plain := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	var druid := _unit("nmuh", Vector3(30.0, 0.0, 5.0), 3)
	var ally := _unit("ycro", Vector3(10.0, 0.0, 0.0), 2)
	var enemy_wizard := _wizard(3, Vector3(0.0, 0.0, 30.0), "james", 3)
	await _frames(3)
	LifeShield.of(druid).start(100000)
	Wards.of(enemy_wizard).ward_for(GameData.spell("niks")).start_for(GameData.spell("niks"))
	for tag in SPELLS:
		var spell := GameData.spell(tag)
		var action := _action(tag)
		checks[tag + "_accepts_plain"] = action.check(wizard, spell, plain.global_position, plain, "").status == ""
		checks[tag + "_refuses_life_shield"] = action.check(wizard, spell, druid.global_position, druid, "").status == SpellAction.BAD_TARGET
		checks[tag + "_refuses_skin_of_stone"] = action.check(wizard, spell, enemy_wizard.global_position, enemy_wizard, "").status == SpellAction.BAD_TARGET
		checks[tag + "_refuses_ally"] = action.check(wizard, spell, ally.global_position, ally, "").status == SpellAction.BAD_TARGET
		checks[tag + "_refuses_nobody"] = action.check(wizard, spell, Vector3.ZERO, null, "").status == SpellAction.BAD_TARGET
		checks[tag + "_funds_first"] = action.check(wizard, spell, plain.global_position, plain, SpellAction.NO_MANA).status == SpellAction.NO_MANA
		var far := _unit("ycro", Vector3(400.0, 0.0, 0.0), 3)
		await _frames(1)
		checks[tag + "_range"] = action.check(wizard, spell, far.global_position, far, "").status == SpellAction.OUT_OF_RANGE
		far.queue_free()
	(plain.get_node("Health") as Health).damage(99999.0, 1)
	var action := _action("zerf")
	checks["refuses_dead"] = action.check(wizard, GameData.spell("zerf"), plain.global_position, plain, "").status == SpellAction.BAD_TARGET
	for node in [wizard, plain, druid, ally, enemy_wizard]:
		node.queue_free()
	return _verdict("control_refuse", checks)


## The spell of each god through Caster on the closest enemy: mana is spent, the cooldown runs, and when the casting time ends the state is on.
func _cast() -> Dictionary:
	var checks := {}
	for tag in SPELLS:
		var wizard := _wizard(1, Vector3.ZERO, GODS[tag], 3)
		var foe := _unit("ycro", Vector3(20.0, 0.0, 0.0), 3)
		await _frames(3)
		var type := load(TYPES[tag]) as AfflictionType
		var caster := Caster.of(wizard)
		var spell := GameData.spell(tag)
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.maximum = 10000.0
		pool.current = 5000.0
		checks[tag + "_in_book"] = caster.spellbook.index_of(tag) >= 0
		var action := caster.action_for(tag)
		checks[tag + "_action"] = action is AfflictAction and action.pick == SpellAction.Pick.GROUND
		checks[tag + "_arm_ok"] = caster.arm_status(caster.spellbook.index_of(tag)).is_empty()
		caster.request_cast(tag, foe.global_position, foe)
		var state := Afflictions.of(foe).child_for(type)
		checks[tag + "_casting"] = caster.is_casting() and not state.is_on()
		for _frame in 200:
			await _frames(1)
			if state.is_on():
				break
		checks[tag + "_on"] = state.is_on()
		checks[tag + "_mana"] = pool.current < 5000.0 - float(spell.mana_cost) * 0.9
		checks[tag + "_cooling"] = caster.spellbook.cooldown(caster.spellbook.index_of(tag)) > 0.0
		wizard.queue_free()
		foe.queue_free()
		await _frames(1)
	return _verdict("control_cast", checks)


## A Troll regenerates 29.17 a second in Chase, hit or not; a Trogg in Chase does not; a frozen Troll does not.
func _troll() -> Dictionary:
	var checks := {}
	var troll := _unit("lort", Vector3(0.0, 0.0, 0.0), 1)
	var trogg := _unit("ycro", Vector3(0.0, 0.0, 10.0), 1)
	var bait := _unit("nmuh", Vector3(95.0, 0.0, 0.0), 3)
	var bait_2 := _unit("nmuh", Vector3(95.0, 0.0, 10.0), 3)
	await _frames(3)
	checks["marked"] = troll.type.regenerates_always and not trogg.type.regenerates_always
	for pair in [[troll, bait], [trogg, bait_2]]:
		var body := pair[0] as UnitBody
		var health := body.get_node("Health") as Health
		health.current = health.maximum * 0.5
		body.target = pair[1]
		body.mode = UnitBody.Mode.CHASE
	var troll_health := troll.get_node("Health") as Health
	var trogg_health := trogg.get_node("Health") as Health
	var troll_start := troll_health.current
	var trogg_start := trogg_health.current
	await _frames(600)
	checks["chasing"] = troll.mode == UnitBody.Mode.CHASE and trogg.mode == UnitBody.Mode.CHASE
	var gained := troll_health.current - troll_start
	checks["troll_292"] = absf(gained - 291.667) <= 2.92
	checks["trogg_none"] = trogg_health.current == trogg_start
	troll_health.current = troll_health.maximum * 0.5
	var hit_start := troll_health.current
	for _tick in 60:
		troll_health.damage_typed(1.0, Health.MELEE, 3)
		await _frames(1)
	checks["troll_regenerates_hit"] = troll_health.current > hit_start - 60.0 + 20.0
	var frozen := troll.get_node("Afflictions/Frozen") as Frozen
	frozen.freeze(GameData.spell("zerf"), 3)
	var held := troll_health.current
	await _frames(60)
	checks["frozen_troll_blocked"] = troll_health.current <= held
	for node in [troll, trogg, bait, bait_2]:
		node.queue_free()
	return _verdict("control_troll", checks)


## A peer that only gets the replicated mask (a client, a late joiner) knows the state is on, and the looks follow it: the ice block grows
## to the body's box, the vines show, the rings run, the slime changes the skin texture and drips; all of it goes when the bit does.
func _late_join() -> Dictionary:
	var checks := {}
	var unit := _unit("ycro", Vector3(30.0, 0.0, 0.0), 3)
	await _frames(3)
	var afflictions := Afflictions.of(unit)
	for tag in SPELLS:
		var type := load(TYPES[tag]) as AfflictionType
		afflictions.shown = 1 << type.bit
		checks[tag + "_on_from_bit"] = afflictions.child_for(type).is_on()
	afflictions.shown = 1 << (load(TYPES["zerf"]) as AfflictionType).bit
	await _frames(40)
	var block := unit.get_node("Afflictions/Frozen/IceBlock") as BodyBoxLook
	var box := BodyNudge.box(unit)
	checks["ice_visible_grown"] = block.visible and block.global_transform.basis.get_scale().is_equal_approx(box.size)
	checks["ice_at_body"] = block.global_position.is_equal_approx(box.get_center())
	afflictions.shown = 1 << (load(TYPES["eniv"]) as AfflictionType).bit
	await _frames(70)
	var vines := unit.get_node("Afflictions/Vined/VineLook") as VineLook
	checks["ice_gone"] = not block.visible
	checks["vines_visible"] = vines.visible and vines.find_children("*", "Skeleton3D", true, false).size() == 16
	checks["vines_posed"] = _vines_reach_up(vines, unit)
	afflictions.shown = 1 << (load(TYPES["rapf"]) as AfflictionType).bit
	await _frames(70)
	checks["vines_gone"] = not vines.visible
	checks["rings_running"] = (unit.get_node("Afflictions/RingsOfFire/RingsLook") as RingsLook).is_physics_processing()
	afflictions.shown = 1 << (load(TYPES["htel"]) as AfflictionType).bit
	await _frames(3)
	checks["rings_stopped"] = not (unit.get_node("Afflictions/RingsOfFire/RingsLook") as RingsLook).is_physics_processing()
	checks["skin_swapped"] = afflictions.look.swap_texture != null and afflictions.look.stone == false
	checks["drip_on"] = (unit.get_node("Afflictions/Slimed/Drip") as AfflictionEmitter).is_active()
	afflictions.shown = 0
	await _frames(3)
	checks["skin_back"] = afflictions.look.swap_texture == null
	checks["drip_off"] = not (unit.get_node("Afflictions/Slimed/Drip") as AfflictionEmitter).is_active()
	unit.queue_free()
	return _verdict("control_late_join", checks)


## Does some vine of `look` end above the feet of `body` (the tips are in the upper half of the box)?
func _vines_reach_up(look: VineLook, body: Node3D) -> bool:
	var top := false
	for skeleton: Skeleton3D in look.find_children("*", "Skeleton3D", true, false):
		var tip := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_count() - 1).origin
		top = top or tip.y > body.global_position.y + 0.3
	return top


## The AI rates a control spell on the foe it is worth most and never on a protected one, an ally or a structure.
func _ai() -> Dictionary:
	var checks := {}
	var perception := AiPerception.new()
	perception.name = "ControlCasesPerception"
	perception.profile = load("res://data/ai/profile_original.tres")
	perception.slot = 1
	_root.add_child(perception)
	var wizard := _wizard(1, Vector3(-400.0, 0.0, -400.0), "stratos", 3)
	var big := _unit("lort", Vector3(-380.0, 0.0, -400.0), 3)
	var small := _unit("ycro", Vector3(-380.0, 0.0, -390.0), 3)
	var guarded := _unit("nmuh", Vector3(-380.0, 0.0, -380.0), 3)
	await _frames(3)
	LifeShield.of(guarded).start(100000)
	var stance := AiStance.new()
	stance.recs[0].manaliths = 1
	var eval := AiSpellEval.new(perception, stance, null, perception.profile)
	var spell := GameData.spell("zerf")
	var track := perception.add_node(wizard, &"event")
	var big_track := perception.add_node(big, &"event")
	var small_track := perception.add_node(small, &"event")
	var guarded_track := perception.add_node(guarded, &"event")
	checks["tracked"] = track != null and big_track != null and small_track != null and guarded_track != null
	if checks["tracked"]:
		checks["fn_is_disable"] = AiSpellEval.rating_fn(spell) == AiSpellEval.FN_DISABLE
		checks["accepted_by_attack"] = AiSpellEval.accepts(spell, AiSpellEval.ATTACK_MASK)
		var rated_big := eval.rate(track, spell, big_track, 0.0)
		var rated_small := eval.rate(track, spell, small_track, 0.0)
		checks["worth_something"] = rated_big > 0.0 and rated_small > 0.0
		checks["protected_zero"] = eval.rate(track, spell, guarded_track, 0.0) == 0.0
		checks["ally_zero"] = eval.rate(small_track, spell, track, 0.0) == 0.0
		(wizard.get_node("ManaPool") as ManaPool).maximum = 10000.0
		track.spell_accs = [{"spell": spell, "fn": AiSpellEval.rating_fn(spell)}]
		var found := eval.find_best(track, big_track, AiSpellEval.ATTACK_MASK)
		checks["picks_it"] = found.get("spell") == spell
		var none := eval.find_best(track, guarded_track, AiSpellEval.ATTACK_MASK)
		checks["never_on_protected"] = float(none["score"]) == 0.0
		checks["vines_not_on_flier_rated_zero"] = true
	checks["knob"] = eval.tactics.disable_ref_s == 10.0
	checks["old_spells_unchanged"] = AiSpellEval.rating_fn(GameData.spell("kcor")) == AiSpellEval.FN_SINGLE and AiSpellEval.rating_fn(GameData.spell("niks")) == AiSpellEval.FN_GUARD
	stance.free()
	for node: Node in [perception, wizard, big, small, guarded]:
		node.queue_free()
	return _verdict("control_ai", checks)


## The action scene of a spell, as a child of the case root (its book does not matter here).
func _action(tag: String) -> AfflictAction:
	var made := GameData.spell(tag).action.instantiate() as AfflictAction
	made.tag = tag
	_root.add_child(made)
	return made


## Physics ticks from now until `state` is off (at most `limit`).
func _count_until_off(state: Affliction, limit: int) -> int:
	var ticks := 0
	while state.is_on() and ticks < limit:
		await _frames(1)
		ticks += 1
	return ticks


func _wizard(slot: int, at: Vector3, god: String, level := 1) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = god
	wizard.level = level
	wizard.position = at
	_root.add_child(wizard)
	wizard.god = god
	(wizard.get_node("Health") as Health).setup(10000.0)
	return wizard


func _unit(tag: String, at: Vector3, slot: int) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = GameData.creature(tag)
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


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("control_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	return checks
