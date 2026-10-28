class_name SacrificeMath
extends RefCounted

## Pure sums of the sacrifice rituals: no nodes, so rules_suite tests them without a world.
## Where the red vortex hangs and where the Sac Doctor lands.

## The search tries the preferred side and then turns by π·step/(numSteps-1) to each side.
const SEARCH_STEPS := 5


## Where the vortex hangs and the doctor lands for a Desecrate:
## the vortex hangs `distance` from the target, on the wizard's side (the offset points from the
## target back toward the caster); the doctor lands halfway between vortex and target. If the landing
## is not on the ground, the offset turns ±45°, ±90°, ±135° and 180° in that order (one side, then the
## other). With no good
## landing the vortex hangs at half the distance and the doctor lands on the target.
## `on_ground` is a Callable(Vector3) -> bool. Positions come back at the height of `target`.
## `beyond`: the vortex hangs past the target as seen from the
## caster instead of on the caster's side.
## Returns {"vortex": Vector3, "landing": Vector3, "step": int (-1 = fallback), "side": int}.
static func drop_positions(
	target: Vector3, caster: Vector3, distance: float, on_ground: Callable, beyond := false
) -> Dictionary:
	var toward := Vector3(target.x - caster.x, 0.0, target.z - caster.z)
	toward = toward.normalized() if toward.length_squared() > 0.000001 else Vector3(0.0, 0.0, 1.0)
	var offset := (distance if beyond else -distance) * toward
	for step in SEARCH_STEPS:
		var sides := 1 if step == 0 or step == SEARCH_STEPS - 1 else 2
		for side in sides:
			var angle := (-1.0 if side == 1 else 1.0) * PI * float(step) / float(SEARCH_STEPS - 1)
			var vortex := target + offset.rotated(Vector3.UP, angle)
			var landing := 0.5 * (vortex + target)
			if on_ground.call(landing):
				return {"vortex": vortex, "landing": landing, "step": step, "side": side}
	return {"vortex": target + 0.5 * offset, "landing": target, "step": -1, "side": 0}


# --- The ritual ---


## Ring position for the k-th doctor (`index` may pass 3: round r
## starts one quarter turn further). `progress` 0..1 is how far
## into the walk phase it is. The radius is 20 m, shrinking by `shrink` in the last fifth of the walk.
static func ring_point(
	center: Vector3, index: int, progress: float, radius := 20.0, shrink := 3.0
) -> Vector3:
	var turns := fposmod(
		0.125 + 0.25 * (float(index) + minf(1.1 * progress, 0.7 + 0.3 * progress)), 1.0
	)
	var angle := turns * TAU - 0.5 * PI
	var r := radius - shrink * maxf(0.0, 5.0 * progress - 4.0)
	return center + Vector3(cos(angle), 0.0, -sin(angle)) * r


## Yaw (Godot, around Y) a doctor at `from` needs to look at `to` on the plane.
static func yaw_toward(from: Vector3, to: Vector3) -> float:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return atan2(flat.x, flat.z) if flat.length_squared() > 0.000001 else 0.0


## Life the Desecrate ritual takes from the wizard in one round.
static func desecrate_health(souls: int, per_round := 200.0) -> float:
	return per_round * float(1 + maxi(souls, 0))


## Mana it takes in one round.
static func desecrate_mana(souls: int, per_round := 40.0) -> float:
	return per_round * float(1 + maxi(souls, 0))


## Rounds of a Convert ritual: it ends when `round == int`, so there
## are that many plus one (the rounds count from 0).
static func convert_rounds(max_health: float, per_round := 550.0) -> int:
	return int(max_health / per_round) + 1


## Where in the schedule `time_s` seconds after the ritual started falls: {"phase": &"setup"|&"walk"|
## &"shoot"|&"wait", "round": int, "t": seconds into that phase}. Pure, for the suite.
static func schedule(
	time_s: float, setup_s := 5.0, walk_s := 4.5, shoot_s := 4.5, wait_s := 4.5
) -> Dictionary:
	if time_s < setup_s:
		return {"phase": &"setup", "round": 0, "t": time_s}
	var round_s := walk_s + shoot_s + wait_s
	var since := time_s - setup_s
	var round_index := int(since / round_s)
	var inside := since - float(round_index) * round_s
	if inside < walk_s:
		return {"phase": &"walk", "round": round_index, "t": inside}
	if inside < walk_s + shoot_s:
		return {"phase": &"shoot", "round": round_index, "t": inside - walk_s}
	return {"phase": &"wait", "round": round_index, "t": inside - walk_s - shoot_s}


# --- Convert ---


## Seconds a Sac Doctor pumps a corpse with `souls` souls: (souls + 1) * 5.
static func pump_seconds(souls: int, per_soul := 5.0) -> float:
	return float(maxi(souls, 0) + 1) * per_soul


## Health a converted corpse stands up with.
static func revive_health(max_health: float, min_health := 400.0, fraction := 0.5) -> float:
	return minf(maxf(min_health, fraction * max_health), max_health)
