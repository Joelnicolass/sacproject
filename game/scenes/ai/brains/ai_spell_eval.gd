class_name AiSpellEval
extends RefCounted

const UnitOrders := preload("res://scenes/units/unit_orders.gd")

## How a wizard rates a spell on a target (shiny.d:2799-2923 `rateSpellAcc`, 2925-2951 `findBestSpell`; RFC-024 §3.1).
## 024c rates the attack spells of the five books: the single-target ones (`f489780`: Rock, Lightning, Insect Swarm) and
## the ones with an area (`f489860`: Wrath, Fireball). 024d adds the support ones of the five books: Heal (`f489af0`) and
## Speedup (`f489c40`). The other evaluators of the original (omna, ndrg Guardian, elet Teleport, protect, `taed`) belong to
## spells the books of the port keep in the tab of structures or do not have, and count 0 («aprox.»). The word `unknown16` of
## the SPEL (low half of the mask at 0x58) is not exported by export_stats.py: it counts as 0 («aprox.»).

## ntt type bits (shiny.d:2672-2680).
const TYPE_WIZ := 1
const TYPE_CRE := 4
const TYPE_STR := 0x10

const ATTACK_MASK := 0x58000000
## wizSupport (shiny.d:3086, 0xa4000000): heal, speedup and the other benefits.
const SUPPORT_MASK := 0xa4000000

## Evaluators (ratingFn): 0 none, 1 single target, 2 area, 3 heal, 4 speedup.
const FN_NONE := 0
const FN_SINGLE := 1
const FN_AREA := 2
const FN_HEAL := 3
const FN_SPEEDUP := 4

var perception: AiPerception
var stance: AiStance
var groups: AiGroups
var profile: AiProfile


func _init(p_perception: AiPerception, p_stance: AiStance, p_groups: AiGroups, p_profile: AiProfile) -> void:
	perception = p_perception
	stance = p_stance
	groups = p_groups
	profile = p_profile


static func type_bits(t: AiTrack) -> int:
	match t.kind:
		AiTrack.Kind.WIZ:
			return TYPE_WIZ
		AiTrack.Kind.CRE, AiTrack.Kind.MAHO:
			return TYPE_CRE
		AiTrack.Kind.STR:
			return TYPE_STR
	return 0


## wantsSpellAcc (shiny.d:322-324): spells with a flags1 in 0xfc00.
static func wants_acc(spell: SpellType) -> bool:
	return (spell.flags1 & 0xfc00) != 0


## Which evaluator a spell uses (ratingFn, shiny.d:334-345: the table of names first, then the flags1 chain).
static func rating_fn(spell: SpellType) -> int:
	match spell.tag:
		"laeh":
			return FN_HEAL
		"pups":
			return FN_SPEEDUP
		"omna", "ndrg", "elet", "ccas", "taed":
			return FN_NONE
	var f1 := spell.flags1
	if f1 & 0x4000:
		return FN_AREA if ((f1 & 0x40) != 0 and spell.effect_range > 0.0) else FN_SINGLE
	if f1 & 0x8000:
		return FN_HEAL
	return FN_NONE


## rater2 vtbl[0] (shiny.d:2656-2661): the spell accepts the mask `(unknown16 | flags1 << 16) & mask`.
static func accepts(spell: SpellType, mask: int) -> bool:
	return (((spell.flags1 << 16) | 0) & mask) != 0


## canCastSpellOn (shiny.d:2756-2797) for the flags of an attack: no ally, a real structure, not a fount.
func can_cast_on(caster: AiTrack, target: AiTrack, spell: SpellType) -> bool:
	var flags := spell.flags
	if flags == 0:
		return true
	if flags & 0x1f:
		if flags & (1 << 11):  # onlyManafounts
			return target.node is ManafountBody and (target.node as ManafountBody).is_free()
		if (flags & (1 << 12)) != 0 and perception.relation_of(target.node) > 1:  # onlyAlly: CREATURE::IsFriendly
			return false
		if flags & (1 << 13):  # disallowAlly
			if perception.relation_of(target.node) <= 1:
				return false
			if target.kind == AiTrack.Kind.STR and target.node.is_in_group(&"manafount"):
				return false
	return true


## rateSpellAcc (shiny.d:2799-2923) for the evaluators of 024c. `dist_scaled` is findBestSpell's (shiny.d:2930-2934).
func rate(caster: AiTrack, spell: SpellType, target: AiTrack, dist_scaled: float) -> float:
	var mask := spell.flags & 0x781f
	if mask != 0 and (type_bits(target) & mask) == 0:
		return 0.0
	if (spell.flags1 & 0x10) != 0 and caster != target:
		return 0.0
	if not can_cast_on(caster, target, spell):
		return 0.0
	if dist_scaled > spell.cast_range * spell.cast_range:
		return 0.0
	match rating_fn(spell):
		FN_SINGLE:
			return _single(spell, target)
		FN_AREA:
			return _area(spell, target)
		FN_HEAL:
			return _heal(spell, target)
		FN_SPEEDUP:
			return _speedup(target)
	return 0.0


## f489780 (shiny.d:2830-2842): worth of the target x the part of its health the spell takes.
func _single(spell: SpellType, target: AiTrack) -> float:
	if (type_bits(target) & 0x15) == 0 or (target.flags & AiTrack.ENEMY) == 0:
		return 0.0
	var hp := perception.health_of(target)
	var m := mini(spell.amount2, hp.x)
	var ratio := AiField.f32(AiField.safediv(float(m), float(hp.y)))
	return AiField.f32(target.sort_key() * ratio)


## f489860 (shiny.d:2843-2847) over aoeSpellBase (shiny.d:2742-2754): the worth of the target, plus the worth of the enemy
## groups the area would hit and minus the own and ally ones.
func _area(spell: SpellType, target: AiTrack) -> float:
	var er := spell.effect_range
	var dr := spell.damage_range
	var rr := dr if dr > er else er
	var r2 := AiField.f32(rr * rr)
	var inv := AiField.f32(AiField.safediv(1.0, r2))
	var base := AiRater.rate(target.acc) if target.kind != AiTrack.Kind.NONE else 0.0
	var amount := spell.damage
	for category in [0, 1, 3]:
		for group: AiGroup in groups.list(category):
			var d2 := group.center.distance_squared_to(target.cur_pos)
			if d2 > r2:
				continue
			var group_rate := AiRater.rate(group.acc)
			var area := (r2 - d2) * float(amount) * inv
			var count := float(group.count)
			var hit := AiRater.ftol(minf(area, count))
			var e := AiField.f32(AiField.safediv(float(hit), float(group.health_sum2)) * group_rate)
			base = AiField.f32(e + base) if category == 3 else AiField.f32(base - e)
	return base


## f489af0 (shiny.d:2873-2884) Heal: worth of the target x the part of its health the spell would give back. Not on an enemy and not
## on one with a heal running (hasActiveHeal).
func _heal(spell: SpellType, target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STR:
		return 0.0
	if target.flags & AiTrack.ENEMY:
		return 0.0
	if target.node.get_node_or_null("HealEffect") != null:
		return 0.0
	var hp := perception.health_of(target)
	if hp.y == 0:
		return 0.0
	var missing := hp.y - hp.x
	var healed := mini(spell.damage, missing)
	return AiField.f32(target.sort_key() * AiField.safediv(float(healed), float(hp.y)))


## f489c40 (shiny.d:2893-2916) Speedup: worth of the target x (its distance to where its order goes)² / base². A creature that
## is advancing (ostate 7; a wizard is left out, and so is one with spells of its own) weighs base 60; one that goes to a soul or
## guards or moves (ostate 34 in the original, 0x22) weighs base 40. Nearer than 10 m to the goal: nothing. A creature that already
## runs faster (a Speedup on it) is the spell's own exclusion: the Caster would answer «Blanco inválido», so it rates 0.
func _speedup(target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STR:
		return 0.0
	if target.node.get_node_or_null("SpeedupEffect") != null:
		return 0.0
	var base := 0.0
	var goal := Vector3.ZERO
	if target.kind == AiTrack.Kind.WIZ:
		if target.ord_state != 34 or not (target.node as WizardBody).is_walking():
			return 0.0
		base = 40.0
		goal = target.ord_pos
	else:
		var orders := target.node.get_node_or_null("Orders")
		if orders == null:
			return 0.0
		var command := int(orders.get("command"))
		var aim: Variant = orders.get("target")
		var point := (aim as Node3D).global_position if aim != null and is_instance_valid(aim) else (orders.get("point") as Vector3)
		if target.ord_state == 7 and command == UnitOrders.Command.ADVANCE:
			var type: Variant = target.node.get("type")
			if type != null and AiPerception._ability_count(type as CreatureType) > 0:
				return 0.0
			base = 60.0
		elif target.ord_state == 34 and (command == UnitOrders.Command.GUARD or command == UnitOrders.Command.GUARD_AREA or command == UnitOrders.Command.MOVE):
			base = 40.0
		else:
			return 0.0
		goal = point
	var d2 := AiField.f32(target.cur_pos.distance_squared_to(goal))
	if d2 < 100.0:
		return 0.0
	return AiField.f32(target.sort_key() * AiField.safediv(d2, base * base))


## findBestSpell (shiny.d:2925-2951): the spell of the wizard's book with the best score against `target`
## (cost paid out of the pool of mana: (1 - cost/pool) * s). Returns {score, spell, range, obj}.
func find_best(caster: AiTrack, target: AiTrack, mask: int) -> Dictionary:
	var pool := float(AiRater.ftol(AiPerception._mana_max(caster.node)) * stance.manalith_count())
	var dist_scaled := 0.0
	if target != null:
		var dse := caster.cur_pos.distance_squared_to(target.cur_pos) * profile.range_distance_scale
		dist_scaled = dse
		if dse < profile.near_distance_sq:
			dist_scaled = 0.0
	var best := 0.0
	var best_spell: SpellType
	for entry: Dictionary in caster.spell_accs:
		var spell: SpellType = entry["spell"]
		if not accepts(spell, mask):
			continue
		var s := rate(caster, spell, target, dist_scaled)
		s = AiField.spell_cost_scaled(s, spell.mana_cost, pool)
		if s > best:
			best = AiField.f32(s)
			best_spell = spell
	if best_spell == null:
		return {"score": 0.0}
	return {"score": best, "spell": best_spell, "range": best_spell.cast_range, "obj": null}
