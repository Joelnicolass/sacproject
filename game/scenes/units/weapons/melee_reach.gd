class_name MeleeReach
extends RefCounted

## Where a melee blow reaches: the box ahead of the body that a swing starts in, lands in and walks
## into. Not: the timing of the swing (MeleeSwing) nor the damage (MeleeRules). The box is 1.3·size
## ahead of the body, size = (width + depth)/4, dimensions (width, depth, 1.5·height); the baked
## body gives width = depth = 2·reach.


## Half width of the melee box at `factor` of its size: the reach, widened by the creature's
## `melee_width_scale`. The box only widens, its forward offset (forward_factor·reach, what close_in
## walks to) does not.
static func box_half(weapon: MeleeWeapon, factor: float) -> float:
	return weapon.reach * (weapon.type.melee_width_scale if weapon.type else 1.0) * factor


static func in_reach(weapon: MeleeWeapon, target: Node3D, factor: float) -> bool:
	var body := weapon.body
	if body == null or target == null or not is_instance_valid(target):
		return false
	var center := (
		body.global_position + MeleeRules.facing_of(body) * (weapon.forward_factor * weapon.reach)
	)
	var half := box_half(weapon, factor)
	var foe := MeleeRules.profile_of(target)
	var foe_reach := float(foe.get("reach", 0.35))
	var at := target.global_position
	if absf(at.x - center.x) > half + foe_reach or absf(at.z - center.z) > half + foe_reach:
		return false
	var box_mid := body.global_position.y + weapon.height * 0.5
	var half_height := weapon.height * weapon.height_factor * 0.5 * factor
	return (
		at.y <= box_mid + half_height
		and at.y + float(foe.get("height", 1.8)) >= box_mid - half_height
	)


## Flat velocity-per-pace (length 0..1) that keeps closing in on `target` while it is in melee
## reach, so a ranged foe ends inside RangedWeapon.melee_distance. Zero once close enough or out of
## reach. The body applies its own pace.
static func close_in(weapon: MeleeWeapon, target: Node3D, pace: float, delta: float) -> Vector3:
	var body := weapon.body
	if (
		body == null
		or target == null
		or pace <= 0.0
		or not in_reach(weapon, target, weapon.start_factor)
	):
		return Vector3.ZERO
	var to_foe := target.global_position - body.global_position
	to_foe.y = 0.0
	var foe_reach := float(MeleeRules.profile_of(target).get("reach", 0.35))
	# The goal never lies inside the distance the avoidance leaves two bodies at (it would steer the
	# walker back every tick).
	var goal := maxf(
		foe_reach + weapon.close_in_factor * weapon.forward_factor * weapon.reach,
		BodyBox.rest_distance(body, target)
	)
	var excess := to_foe.length() - goal
	var walk := (
		Vector3.ZERO
		if excess <= 0.0 or delta <= 0.0
		else to_foe.normalized() * minf(pace, excess / delta)
	)
	if DebugLog.on(&"gap"):
		var radius := BodyBox.half_size(body)
		var foe_radius := BodyBox.half_size(target)
		print(
			(
				# gdlint: ignore=max-line-length
				"melee_gap %s->%s d=%.3f gap=%.3f vx=%.3f vz=%.3f tick=%d reach=%.3f foe_reach=%.3f radius=%.3f foe_radius=%.3f axis_gap=%.3f"
				% [
					body.name,
					target.name,
					to_foe.length(),
					to_foe.length() - radius - foe_radius,
					walk.x,
					walk.z,
					MatchClock.now(),
					weapon.reach,
					foe_reach,
					radius,
					foe_radius,
					maxf(absf(to_foe.x), absf(to_foe.z)) - radius - foe_radius
				]
			)
		)
	return walk
