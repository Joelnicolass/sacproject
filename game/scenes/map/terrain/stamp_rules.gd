class_name StampRules
extends RefCounted

## The arithmetic of a stamp with no tree: how far each vertex of the lattice is raised (or lowered) by a StampProfile of
## a given reach and peak, centred at a point, some seconds after it started. Pure and static, so a test can ask it
## without a map. Who plays it over time is TerrainStamp; who keeps the result is TerrainDeformer.


## The shift of every vertex of `rect` (row by row) caused by `profile` at `local_s` seconds. `center` is x, z in metres.
static func values(profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, local_s: float, rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	var amount := peak_m * profile.timeline.sample(local_s)
	if amount == 0.0 or local_s >= profile.duration_s():
		return out
	var ring_at := profile.ring_travel.sample(local_s) if profile.is_ring() else 0.0
	var half := maxf(profile.ring_width.sample(local_s), 0.001) if profile.is_ring() else maxf(reach_m, 0.001)
	for row in rect.size.y:
		for column in rect.size.x:
			var spot := Vector2(rect.position + Vector2i(column, row)) * TerrainRules.CELL
			var across := absf(spot.distance_to(center) - ring_at) / half
			if across < 1.0:
				out[row * rect.size.x + column] = amount * profile.radial.sample(across)
	return out
