class_name AiField
extends RefCounted

## The scalar fields of the AI as pure functions: how much a distance
## weighs, how groups influence a point, how the three casting weights split. Each line names the
## `shiny.d` line it was ported from. Floats the engine stores as `float` go through f32().
## Ref: RFC-024 §3.1 `AiField`.

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


## A group of `count` takes a body within group_radius_m * min(1 + group_growth * count, group_cap) of its center (the crowd
## tactics; the cap goes through float32 like the original's 1.8). ## Ref: shiny.d:1702-1710 canAccept.
static func group_radius(count: int, crowd: AiCrowdTactics) -> float:
	var r := float(count) * crowd.group_growth + 1.0
	var cap := f32(crowd.group_cap)
	if not (r < cap):
		r = cap
	return r * crowd.group_radius_m


static func can_accept(count: int, distance_sq: float, crowd: AiCrowdTactics) -> bool:
	var r := group_radius(count, crowd)
	return not (r * r < distance_sq)


## weightTriple (shiny.d:2953-2966, 0x48cc70): the weights of attacking, supporting and converting.
## `ratio` is stanceRecs[3] u[6] (own souls / (own + enemy)), `task` the kind of the record's task: guard and capture have their
## own split; idle and focus (the original's idle number, which neither branch takes) split evenly.
static func weight_triple(task: AiTask.Kind, ratio: float, aggression: float) -> Array[float]:
	var m := 1.0 - ratio
	var o0 := 0.0
	var o1 := 0.0
	var o2 := 0.0
	if task == AiTask.Kind.GUARD:
		o0 = f32(aggression * (1.0 - m) * (1.0 / 6.0))
		o1 = f32(1.0 - m)
		o2 = m * aggression
	elif task == AiTask.Kind.CAPTURE:
		o0 = f32(aggression * (1.0 - m) * 0.5)
		o1 = f32((1.0 - m) * (1.0 / 3.0))
		o2 = m * aggression
	var total := (o2 + o1) + o0
	if total <= 0.0:
		return [0.333299994468689, 0.333299994468689, 0.333299994468689]
	return [f32(safediv(o0, total)), f32(safediv(o1, total)), f32(safediv(o2, total))]


## The weight a foe has for the wizard's attack: 1 within 10 m; (thr-d)/(thr-10) up to `thr`; times the tactics' weight_passive
## when it does not fight, weight_no_ability when it has no ability it can pay now (`able`: AiBody.ability_ready), weight_sac_doctor
## for a Sac Doctor. 0 when the foe is out of reach. 055f f5: the original read bits only a wizard or a ready Manahoar carried, so
## every creature weighed x0.5 and x1/3 whatever it could do. ## Ref: shiny.d:3052-3071 (0x48d640).
static func attack_weight(distance: float, thr: float, foe: AiTrack, able: bool, tactics: AiTactics, sac_doctor := false) -> float:
	var w := 0.0
	if distance <= 10.0:
		w = 1.0
	elif not (distance < thr):
		return 0.0
	else:
		w = safediv(thr - distance, thr - 10.0)
		if w == 0.0:
			return 0.0
	if not foe.fights:
		w *= tactics.weight_passive
	if not able:
		w *= tactics.weight_no_ability
	if sac_doctor:
		w *= tactics.weight_sac_doctor
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
