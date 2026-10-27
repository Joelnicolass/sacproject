class_name AiHealRating
extends RefCounted

## How much a Heal or a Speedup on an own body is worth, and whether a queued Heal still is. It does not pick the spell
## (AiSpellEval) and it does not cast. Static.
## Ref: shiny.d:2873-2884 f489af0 (Heal), 2893-2916 f489c40 (Speedup)

const UnitOrders := preload("res://scenes/units/unit_orders.gd")


## Heal: worth of the target x the part of its health the spell would give back. Not on an enemy and not on one with a heal running
## (hasActiveHeal). RFC-053 053c (F372): nor on a body at or over `heal_below_ratio` of its health, nor on one that misses less than
## `heal_min_missing`, nor on one still being summoned (the original heals whatever is not full).
static func heal(spell: SpellType, target: AiTrack, perception: AiPerception, tactics: AiTactics) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STRUCTURE:
		return 0.0
	if target.relation == AiTrack.Relation.ENEMY:
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
static func still_worth(spell: Resource, target: AiTrack, perception: AiPerception, tactics: AiTactics) -> bool:
	if not (spell is SpellType) or target == null or AiSpellEval.rating_fn(spell as SpellType) != AiSpellEval.FN_HEAL:
		return true
	return heal(spell as SpellType, target, perception, tactics) > 0.0


## Speedup: worth of the target x (its distance to where its order goes)² / base². A creature that is advancing (ostate 7; a wizard
## is left out, and so is one with spells of its own) weighs base 60; one that goes to a soul or guards or moves (AiOrder.TAKE_SOUL,
## the original's ostate 0x22) weighs base 40. Nearer than 10 m to the goal: nothing. A creature that already runs faster (a Speedup
## on it) is the spell's own exclusion: the Caster would answer «Blanco inválido», so it rates 0.
static func speedup(target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STRUCTURE:
		return 0.0
	if target.node.get_node_or_null("SpeedupEffect") != null:
		return 0.0
	var base := 0.0
	var goal := Vector3.ZERO
	if target.kind == AiTrack.Kind.WIZARD:
		if target.ord_state != AiCommandPort.AiOrder.TAKE_SOUL or not (target.node as WizardBody).is_walking():
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
		if target.ord_state == AiCommandPort.AiOrder.ADVANCE and command == UnitOrders.Command.ADVANCE:
			var type: Variant = target.node.get("type")
			if type != null and AiTrackFacts.ability_count(type as CreatureType) > 0:
				return 0.0
			base = 60.0
		elif target.ord_state == AiCommandPort.AiOrder.TAKE_SOUL and (command == UnitOrders.Command.GUARD or command == UnitOrders.Command.GUARD_AREA or command == UnitOrders.Command.MOVE):
			base = 40.0
		else:
			return 0.0
		goal = point
	var d2 := AiField.f32(target.cur_pos.distance_squared_to(goal))
	if d2 < 100.0:
		return 0.0
	return AiField.f32(target.sort_key() * AiField.safediv(d2, base * base))
