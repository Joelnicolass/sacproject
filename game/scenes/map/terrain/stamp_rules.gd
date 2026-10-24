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


## The height of each lattice vertex of `rect` (row by row) with what stays on the ground but not the stamps that are playing
## (NAN over a hole or off the land): what a stamp that starts now flattens. Every peer has the same permanent ground.
static func ground_under(shape: TerrainShape, rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	var ground := shape.displacement()
	for row in rect.size.y:
		for column in rect.size.x:
			var id := (rect.position.y + row) * TerrainDisplacement.SIDE + rect.position.x + column
			var spot := Vector2(rect.position + Vector2i(column, row)) * TerrainRules.CELL
			out[row * rect.size.x + column] = shape.height_at(spot.x, spot.y) - ground.at(id) + ground.permanent[id]
	return out


## The shift a picture stamp makes at its full size, vertex by vertex of `rect` (row by row): `peak_m` times the grey of the pixel
## under the vertex, plus the share of the way from the vertex's ground to `target_y` that `flatten` gives at its square distance
## to the center. `ground` holds the height of each vertex of `rect` before the stamp (NAN = none). Worked out once, when the stamp
## starts; `scaled` plays it over time. `center` is x, z in metres and lies on the lattice.
static func pattern(profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, rect: Rect2i, ground: PackedFloat32Array, target_y: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	var picture := profile.heightmap.get_image() if profile.heightmap != null else null
	for row in rect.size.y:
		for column in rect.size.x:
			var offset := Vector2(rect.position + Vector2i(column, row)) * TerrainRules.CELL - center
			if maxf(absf(offset.x), absf(offset.y)) > reach_m + 0.001:
				continue
			var at := row * rect.size.x + column
			var value := 0.0
			if profile.flatten != null and not is_nan(ground[at]):
				value = (target_y - ground[at]) * profile.flatten.sample(maxf(absf(offset.x), absf(offset.y)) / maxf(reach_m, 0.001))
			if picture != null:
				var pixel := Vector2i((offset / profile.heightmap_m).round()) + Vector2i(picture.get_size() / 2)
				if pixel.x >= 0 and pixel.y >= 0 and pixel.x < picture.get_width() and pixel.y < picture.get_height():
					value += peak_m * picture.get_pixelv(pixel).r
			out[at] = value
	return out


## A pattern at `local_s` seconds: itself times the share the timeline gives (zeros once the stamp is over).
static func scaled(profile: StampProfile, shape: PackedFloat32Array, local_s: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(shape.size())
	if local_s >= profile.duration_s():
		return out
	var share := profile.timeline.sample(local_s)
	for k in shape.size():
		out[k] = shape[k] * share
	return out
