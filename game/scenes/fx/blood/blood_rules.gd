class_name BloodRules
extends RefCounted

## The sums of bleeding, with no tree: whether a drop of health bleeds (none, light or heavy) and
## where the marks of a spray land. It also packs a wound for the wire (wound_of / index_of /
## is_heavy).
## What it does not do: touch nodes, FxBus or GroundScars, or use the global random generator (the
## caller hands its own).

enum Kind { NONE, LIGHT, HEAVY }


## `drop_share`: this drop over the maximum health. `lost_share`: what was lost since the last
## spray, this drop included. `since_spray_s` / `since_drop_s`: seconds since the last spray / the
## drop before this one (INF when none). A drop bleeds once `every_s` has passed since the last
## spray, and only if it is isolated (no other drop within `every_s`) or the drops close together
## add up to `min_lost`: a blow always bleeds, a poison bleeds now and then.
static func kind_for(
	drop_share: float, lost_share: float, since_spray_s: float, since_drop_s: float, type: BloodType
) -> Kind:
	if type == null or not type.bleeds() or drop_share <= 0.0:
		return Kind.NONE
	if since_spray_s < type.every_s:
		return Kind.NONE
	var isolated := since_drop_s >= type.every_s
	if not isolated and lost_share < type.min_lost:
		return Kind.NONE
	return Kind.HEAVY if drop_share >= type.heavy_from else Kind.LIGHT


## `count` points spread evenly over a disc of `radius_m` around `center` (same height as `center`).
static func mark_points(
	center: Vector3, count: int, radius_m: float, rng: RandomNumberGenerator
) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in maxi(count, 0):
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * maxf(radius_m, 0.0)
		points.append(center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
	return points


## A wound as the network carries it: xyz = the feet where it landed, w = 2 * index + heavy (exact
## in a float up to 2^23 wounds).
static func wound_of(feet: Vector3, index: int, heavy: bool) -> Vector4:
	return Vector4(feet.x, feet.y, feet.z, float(maxi(index, 0) * 2 + (1 if heavy else 0)))


## Which wound of the body it is (1, 2, …); 0 = none yet.
static func index_of(wound: Vector4) -> int:
	return maxi(roundi(wound.w), 0) >> 1


static func is_heavy(wound: Vector4) -> bool:
	return (maxi(roundi(wound.w), 0) & 1) == 1
