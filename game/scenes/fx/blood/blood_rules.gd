class_name BloodRules
extends RefCounted

## The sums of bleeding, with no tree: whether a drop of health bleeds (none, light or heavy) and where the marks of a spray land.
## What it does not do: touch nodes, FxBus or GroundScars, or use the global random generator (the caller hands its own).

enum Kind { NONE, LIGHT, HEAVY }


## `drop_share`: this drop over the maximum health. `lost_share`: what was lost since the last spray, this drop included.
## `since_spray_s` / `since_drop_s`: seconds since the last spray / the drop before this one (INF when none).
## A drop bleeds once `every_s` has passed since the last spray, and only if it is isolated (no other drop within `every_s`) or the
## drops close together add up to `min_lost`: a blow always bleeds, a poison bleeds now and then.
static func kind_for(drop_share: float, lost_share: float, since_spray_s: float, since_drop_s: float, type: BloodType) -> Kind:
	if type == null or not type.bleeds() or drop_share <= 0.0:
		return Kind.NONE
	if since_spray_s < type.every_s:
		return Kind.NONE
	var isolated := since_drop_s >= type.every_s
	if not isolated and lost_share < type.min_lost:
		return Kind.NONE
	return Kind.HEAVY if drop_share >= type.heavy_from else Kind.LIGHT


## `count` points spread evenly over a disc of `radius_m` around `center` (same height as `center`).
static func mark_points(center: Vector3, count: int, radius_m: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in maxi(count, 0):
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * maxf(radius_m, 0.0)
		points.append(center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
	return points
