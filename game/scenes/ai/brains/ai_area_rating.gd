class_name AiAreaRating
extends RefCounted

## How much an area spell is worth where it bursts, and how much of an own body its burst would take. The worth is the target's,
## plus the enemy groups the area would hit and minus the own and ally ones. It does not pick the spell (AiSpellEval) and it does
## not hold the cast back (AiShotCheck asks `own_splash`). Static. Ref: shiny.d:2843-2847 f489860, 2742-2754 aoeSpellBase.


## The worth of the area of `spell` bursting at `point` on `target`. RFC-053 053b: an own or ally group counts by its members within
## the area of `point` (the nearest one gives the distance), not by its center: a Ranger at 1 m of the burst weighs even if the rest of
## its group stands far. The only casts the wizard releases burst on the target (AiLineOfFire: a blocked shot walks instead), so the
## rating's `point` is the target.
static func rate(spell: SpellType, target: AiTrack, point: Vector3, groups: AiGroups) -> float:
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
			## 055f f6: a group whose health the side does not know (never seen) weighs nothing, instead of hit / 0 = INF.
			if group.health_sum2 <= 0:
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
static func own_splash(point: Vector3, spell: SpellType, direct: Node3D, perception: AiPerception, tactics: AiTactics) -> float:
	var worst := 0.0
	for own: AiTrack in perception.bodies(0):
		if not own.is_valid():
			continue
		if own.kind == AiTrack.Kind.WIZARD and not tactics.own_splash_counts_wizard:
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
