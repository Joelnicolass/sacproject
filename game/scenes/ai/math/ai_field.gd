class_name AiField
extends RefCounted

## The scalar fields of the original AI as pure functions (RFC-024 §3.1 `AiField`): how much a distance
## weighs, how groups influence a point, how the three casting weights split. Each line names the
## `shiny.d` line it was ported from. Floats the engine stores as `float` go through f32().

## A float32 round trip (the engine keeps most of these in float).
static func f32(x: float) -> float:
	var a := PackedFloat32Array([x])
	return a[0]


## safediv (shiny.d:199-206): a NaN answer becomes the canonical NaN; infinities pass.
static func safediv(a: float, b: float) -> float:
	var r := a / b
	return NAN if is_nan(r) else r


## lerp(a, w, b) = a + (b - a) * w (shiny.d:2011 `lerp`, 0x48abe0).
static func lerp_w(a: float, w: float, b: float) -> float:
	return f32(a + (b - a) * w)


## The linear falloff every scan uses: 1 up to `near`, 0 from `far`, (far - d) / (far - near) between
## (shiny.d:2012-2040 probOr, 2042-2062 densityGroups, 2064-2082 influenceGroups).
static func ramp(distance: float, near: float, far: float) -> float:
	if distance <= near:
		return 1.0
	if distance >= far:
		return 0.0
	return f32(safediv(far - distance, far - near))


## probOr (shiny.d:2012-2022): acc += w*w*(1-acc) for each distance.
static func prob_or(distances: PackedFloat32Array, near: float, far: float) -> float:
	var acc := 0.0
	for d in distances:
		var w := ramp(d, near, far)
		acc = f32(acc + w * w * (1.0 - acc))
	return acc


## canAccept (shiny.d:1702-1710): a group of `count` takes a body within 30*min(1+0.1*count, 1.8) m of its center.
static func group_radius(count: int) -> float:
	var r := float(count) * 0.1 + 1.0
	if not (r < 1.7999999523162842):
		r = 1.7999999523162842
	return r * 30.0


static func can_accept(count: int, distance_sq: float) -> bool:
	var r := group_radius(count)
	return not (r * r < distance_sq)


## weightTriple (shiny.d:2953-2966, 0x48cc70): the weights of attacking, supporting and converting.
## `ratio` is stanceRecs[3] u[6] (own souls / (own + enemy)), `command` 0..2 the record's task command.
static func weight_triple(command: int, ratio: float, aggression: float) -> Array[float]:
	var m := 1.0 - ratio
	var o0 := 0.0
	var o1 := 0.0
	var o2 := 0.0
	if command <= 1:
		o0 = f32(aggression * (1.0 - m) * (1.0 / 6.0))
		o1 = f32(1.0 - m)
		o2 = m * aggression
	elif command == 2:
		o0 = f32(aggression * (1.0 - m) * 0.5)
		o1 = f32((1.0 - m) * (1.0 / 3.0))
		o2 = m * aggression
	var total := (o2 + o1) + o0
	if total <= 0.0:
		return [0.333299994468689, 0.333299994468689, 0.333299994468689]
	return [f32(safediv(o0, total)), f32(safediv(o1, total)), f32(safediv(o2, total))]


## The weight a foe has for wizAttack (shiny.d:3052-3071, 0x48d640): 1 within 10 m; (thr-d)/(thr-10) up to `thr`;
## halved when it is not aggressive/wizard-like (status & 6 == 0), a third when it has no ready ability
## (status & 0x1800 == 0), x10 for a Sac Doctor. 0 when the foe is out of reach.
static func attack_weight(distance: float, thr: float, status: int, sac_doctor: bool) -> float:
	var w := 0.0
	if distance <= 10.0:
		w = 1.0
	elif not (distance < thr):
		return 0.0
	else:
		w = safediv(thr - distance, thr - 10.0)
		if w == 0.0:
			return 0.0
	if (status & 0x6) == 0:
		w *= 0.5
	if (status & 0x1800) == 0:
		w *= 0.3333333432674408
	if sac_doctor:
		w *= 10.0
	return w


## `thr` of wizAttack: (1 - threat) * 280 (retail coefficient 280, shiny.d:3055; 180 is the beta).
static func attack_reach(threat: float, coefficient: float) -> float:
	return f32((1.0 - threat) * coefficient)


## The score of a spell once the cost is paid out of the pool (findBestSpell, shiny.d:2938-2943): (1 - cost/pool)*s.
static func spell_cost_scaled(score: float, mana_cost: int, pool: float) -> float:
	if pool > 0.0:
		return (1.0 - safediv(float(mana_cost), pool)) * score
	return score


## wizSacrifice BLOCK2 (shiny.d:3155-3162): (1 - cost/pool)*s for a positive rating, cost/pool*s otherwise.
static func summon_score(rating: float, mana_cost: int, pool: int) -> float:
	var cost := safediv(float(mana_cost), float(pool))
	return (1.0 - cost) * rating if rating > 0.0 else cost * rating
