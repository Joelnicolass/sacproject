class_name AiSpellEval
extends RefCounted

const UnitOrders := preload("res://scenes/units/unit_orders.gd")

## How the wizard of the AI rates a spell on a target and picks the best one of his book. It reads only the named fields of the
## SpellType (`ai_use`, `ai_phase`, the «who it may land on» ticks, `ai_worth`); it does not cast and it does not look at tags.
## A spell the AI has no evaluator for rates 0. ## Ref: shiny.d:2799-2923 `rateSpellAcc`, 2925-2951 `findBestSpell`; RFC-024 §3.1.
## ntt type bits (shiny.d:2672-2680).
const TYPE_WIZ := 1
const TYPE_CRE := 4
const TYPE_STR := 0x10

## Evaluators (ratingFn): 0 none, 1 single target, 2 area, 3 heal, 4 speedup, 5 guard (a ward on himself), 6 disable (a control spell on a foe).
const FN_NONE := 0
const FN_SINGLE := 1
const FN_AREA := 2
const FN_HEAL := 3
const FN_SPEEDUP := 4
const FN_GUARD := 5
const FN_DISABLE := 6
const FN_OF_USE := {SpellType.AiUse.HIT_ONE: FN_SINGLE, SpellType.AiUse.HIT_AREA: FN_AREA, SpellType.AiUse.HEAL: FN_HEAL,
	SpellType.AiUse.SPEEDUP: FN_SPEEDUP, SpellType.AiUse.SELF_GUARD: FN_GUARD, SpellType.AiUse.DISABLE_FOE: FN_DISABLE}

var perception: AiPerception
var stance: AiStance
var groups: AiGroups
var profile: AiProfile
## RFC-053: the common sense of the difficulty (set by AiWizardBrain.prepare; Normal's until then).
var tactics: AiTactics = AiTactics.or_normal(null)


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


## The AI keeps in its book list the spells it may cast on its own: those with a phase (attack or support).
static func wants_acc(spell: SpellType) -> bool:
	return spell.ai_phase != SpellType.AiPhase.NEVER


## Which evaluator a spell uses, from what the .tres says it is for (`ai_use`). The altar spells (Convert, Desecrate) have their own
## phases and no rating.
static func rating_fn(spell: SpellType) -> int:
	return int(FN_OF_USE.get(spell.ai_use, FN_NONE))


## Whether the spell is cast in this phase (attack on a foe, support of an own body).
static func casts_in(spell: SpellType, phase: SpellType.AiPhase) -> bool:
	return phase != SpellType.AiPhase.NEVER and spell.ai_phase == phase


## Whether the kind of the target is one the spell lands on (a spell with none of the nine ticks lands on anything).
static func lands_on(spell: SpellType, target: AiTrack) -> bool:
	if not (_names_a_kind(spell) or spell.only_free_manafounts or spell.only_allies or spell.never_allies or spell.targets_ground):
		return true
	match target.kind:
		AiTrack.Kind.WIZ:
			return spell.targets_wizards
		AiTrack.Kind.CRE, AiTrack.Kind.MAHO:
			return spell.targets_creatures
		AiTrack.Kind.STR:
			return spell.targets_structures
	return false


## Whether the spell may land on this target by side: no ally, a real structure, not a fount.
func can_cast_on(_caster: AiTrack, target: AiTrack, spell: SpellType) -> bool:
	if not _names_a_kind(spell):
		return true
	var free_fount := spell.only_free_manafounts and target.node is ManafountBody and (target.node as ManafountBody).is_free()
	return side_allows(spell, free_fount, perception.relation_of(target.node),
		target.kind == AiTrack.Kind.STR and target.node.is_in_group(&"manafount"))


## The side rule of can_cast_on over facts already looked up (relation: 0 own, 1 ally, 2 or 3 not an ally). A free manafount is all
## that `only_free_manafounts` takes; after it `only_allies`, then `never_allies` (which also refuses a manafount structure).
static func side_allows(spell: SpellType, free_fount: bool, relation: int, fount_structure: bool) -> bool:
	if not _names_a_kind(spell):
		return true
	if spell.only_free_manafounts:
		return free_fount
	if spell.only_allies and relation > 1:
		return false
	if spell.never_allies:
		return relation > 1 and not fount_structure
	return true


static func _names_a_kind(spell: SpellType) -> bool:
	return spell.targets_wizards or spell.targets_souls or spell.targets_creatures or spell.targets_corpses or spell.targets_structures


## rateSpellAcc (shiny.d:2799-2923) for the evaluators of 024c. `dist_scaled` is findBestSpell's (shiny.d:2930-2934).
func rate(caster: AiTrack, spell: SpellType, target: AiTrack, dist_scaled: float) -> float:
	if not lands_on(spell, target):
		return 0.0
	if spell.ai_only_on_self and caster != target:
		return 0.0
	if not can_cast_on(caster, target, spell):
		return 0.0
	if dist_scaled > spell.cast_range_m * spell.cast_range_m:
		return 0.0
	match rating_fn(spell):
		FN_SINGLE:
			return _single(spell, target)
		FN_AREA:
			return _area(spell, target, target.cur_pos)
		FN_HEAL:
			return _heal(spell, target)
		FN_SPEEDUP:
			return _speedup(target)
		FN_GUARD:
			return AiGuard.rate(spell, target, perception, tactics)
		FN_DISABLE:
			return AiDisable.rate(spell, caster, target, tactics)
	return 0.0


## f489780 (shiny.d:2830-2842): worth of the target x the part of its health the spell takes.
func _single(spell: SpellType, target: AiTrack) -> float:
	if (type_bits(target) & 0x15) == 0 or (target.flags & AiTrack.ENEMY) == 0:
		return 0.0
	var hp := perception.health_of(target)
	var m := mini(spell.ai_worth, hp.x)
	var ratio := AiField.f32(AiField.safediv(float(m), float(hp.y)))
	return AiField.f32(target.sort_key() * ratio)


## f489860 (shiny.d:2843-2847) over aoeSpellBase (shiny.d:2742-2754): the worth of the target, plus the worth of the enemy
## groups the area would hit and minus the own and ally ones. `point` is where it bursts. RFC-053 053b: an own or ally group counts
## by its members within the area of `point` (the nearest one gives the distance), not by its center: a Ranger at 1 m of the burst
## weighs even if the rest of its group stands far. The only casts the wizard releases burst on the target (AiLineOfFire: a blocked
## shot walks instead), so the rating's `point` is the target.
func _area(spell: SpellType, target: AiTrack, point: Vector3) -> float:
	var er := spell.effect_range_m
	var dr := spell.damage_range_m
	var rr := dr if dr > er else er
	var r2 := AiField.f32(rr * rr)
	var inv := AiField.f32(AiField.safediv(1.0, r2))
	var base := AiRater.rate(target.acc) if target.kind != AiTrack.Kind.NONE else 0.0
	var amount := spell.damage
	for category in [0, 1, 3]:
		for group: AiGroup in groups.list(category):
			var d2 := group.center.distance_squared_to(point) if category == 3 else _nearest_member_d2(group, point)
			if d2 > r2:
				continue
			var group_rate := AiRater.rate(group.acc)
			var area := (r2 - d2) * float(amount) * inv
			var count := float(group.count)
			var hit := AiRater.ftol(minf(area, count))
			var e := AiField.f32(AiField.safediv(float(hit), float(group.health_sum2)) * group_rate)
			base = AiField.f32(e + base) if category == 3 else AiField.f32(base - e)
	return base


## The squared distance from `point` to the nearest member of `group` (INF with none).
static func _nearest_member_d2(group: AiGroup, point: Vector3) -> float:
	var best := INF
	for member in group.members:
		if member != null and member.is_valid():
			best = minf(best, member.cur_pos.distance_squared_to(point))
	return best


## RFC-053 053b: the largest fraction of its maximum health any own body would lose to a burst of `spell` at `point` (SplashDamage:
## the body it bursts on, `direct`, takes the whole amount; the rest amount·(1 − d/damage_range) by the distance to their hit box;
## the side factor of Health, so with friendly fire off an own body loses 0). The wizard counts when the tactics say so. Own bodies
## only: the side knows them.
func own_splash(point: Vector3, spell: SpellType, direct: Node3D = null) -> float:
	var worst := 0.0
	for own: AiTrack in perception.bodies(0):
		if not own.is_valid():
			continue
		if own.kind == AiTrack.Kind.WIZ and not tactics.own_splash_counts_wizard:
			continue
		worst = maxf(worst, splash_loss(own.node, point, spell, perception.slot, own.node == direct))
	return worst


## What a burst of `spell` at `point` from `from_slot` takes from `body`, as a fraction of its maximum health.
static func splash_loss(body: Node3D, point: Vector3, spell: SpellType, from_slot: int, direct := false) -> float:
	var health := body.get_node_or_null("Health") as Health
	if health == null or health.maximum <= 0.0:
		return 0.0
	var amount := float(spell.damage)
	if not direct:
		if spell.damage_range_m <= 0.0:
			return 0.0
		amount *= maxf(0.0, 1.0 - SplashDamage.box_distance(body, point) / spell.damage_range_m)
	return amount * health.side_factor(from_slot) / health.maximum


## f489af0 (shiny.d:2873-2884) Heal: worth of the target x the part of its health the spell would give back. Not on an enemy and not
## on one with a heal running (hasActiveHeal). RFC-053 053c (F372): nor on a body at or over `heal_below_ratio` of its health, nor on
## one that misses less than `heal_min_missing`, nor on one still being summoned (the original heals whatever is not full).
func _heal(spell: SpellType, target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STR:
		return 0.0
	if target.flags & AiTrack.ENEMY:
		return 0.0
	if target.node.get_node_or_null(HealEffect.NODE_NAME) != null:
		return 0.0
	if target.node is UnitBody and (target.node as UnitBody).is_summoning():
		return 0.0
	var hp := perception.health_of(target)
	if hp.y == 0:
		return 0.0
	var missing := hp.y - hp.x
	if float(hp.x) >= tactics.heal_below_ratio * float(hp.y) or float(missing) < tactics.heal_min_missing:
		return 0.0
	var healed := mini(spell.damage, missing)
	return AiField.f32(target.sort_key() * AiField.safediv(float(healed), float(hp.y)))


## F372: whether a queued Heal on `target` still rates over 0 with the health the side knows now (the queue can be 16 ticks old).
## Any other spell answers true.
func still_worth(spell: Resource, target: AiTrack) -> bool:
	if not (spell is SpellType) or target == null or rating_fn(spell as SpellType) != FN_HEAL:
		return true
	return _heal(spell as SpellType, target) > 0.0


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
func find_best(caster: AiTrack, target: AiTrack, phase: SpellType.AiPhase) -> Dictionary:
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
		if not casts_in(spell, phase):
			continue
		var s := rate(caster, spell, target, dist_scaled)
		s = AiField.spell_cost_scaled(s, spell.mana_cost, pool)
		if s > best:
			best = AiField.f32(s)
			best_spell = spell
	if best_spell == null:
		return {"score": 0.0}
	return {"score": best, "spell": best_spell, "range": best_spell.cast_range_m, "obj": null}
