class_name MeshGroundRules
extends RefCounted

## The arithmetic of a mesh ground with no tree: which walkable triangle lies under a point, how high the land is there, and how
## the triangles of a MeshGroundData are filed in buckets so that question is one lookup. When two walkable triangles cover
## the same point (a roof over a floor) the HIGHER one wins; walls (a triangle leaning more than `walkable_deg`) collide but
## give no height. Pure and static, so a WorkerThreadPool task can call it on the data. What it does NOT do: hold the data
## (MeshGroundData), answer for the map (GroundSurface) or move the ground (GroundField).

## Edge tolerance of the inside test; a point on an edge counts as inside.
const EDGE_TOLERANCE := 0.0001
## A triangle is filed under the buckets its footprint touches, grown by this much so an edge on a bucket line is in both.
const BUCKET_MARGIN_M := 0.001


## The walkable triangle under (x, z) (an id: corners are `indices[id * 3 ...]`), -1 off the land.
static func triangle_in(x: float, z: float, data: MeshGroundData) -> int:
	var bucket := _bucket_of(x, z, data)
	if bucket < 0:
		return -1
	var vertices := data.vertices
	var indices := data.indices
	var tris := data.bucket_tris
	var at := Vector2(x, z)
	var best := -1
	var best_y := -INF
	for k: int in range(data.bucket_start[bucket], data.bucket_start[bucket + 1]):
		var id := tris[k]
		var a := vertices[indices[id * 3]]
		var b := vertices[indices[id * 3 + 1]]
		var c := vertices[indices[id * 3 + 2]]
		if not _inside(a, b, c, at):
			continue
		var y := _plane_y(a, b, c, x, z)
		if y > best_y:
			best_y = y
			best = id
	return best


## Land height under (x, z) in world units, NAN off the land.
static func height_in(x: float, z: float, data: MeshGroundData) -> float:
	var id := triangle_in(x, z, data)
	if id < 0:
		return NAN
	return _plane_y(data.vertices[data.indices[id * 3]], data.vertices[data.indices[id * 3 + 1]], data.vertices[data.indices[id * 3 + 2]], x, z)


## Unit normal (pointing up) of the land under (x, z); straight up off the land.
static func normal_in(x: float, z: float, data: MeshGroundData) -> Vector3:
	var id := triangle_in(x, z, data)
	if id < 0:
		return Vector3.UP
	return face_normal(data.vertices[data.indices[id * 3]], data.vertices[data.indices[id * 3 + 1]], data.vertices[data.indices[id * 3 + 2]]).normalized()


## The normal of a triangle (not unit length) on the side Godot draws it: clockwise corners seen from the front.
static func face_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return (c - a).cross(b - a)


## True for a triangle you can stand on: it faces up and leans no more than the angle whose cosine is `min_up`.
static func is_walkable(a: Vector3, b: Vector3, c: Vector3, min_up: float) -> bool:
	var normal := face_normal(a, b, c)
	var length := normal.length()
	return length > 1e-9 and normal.y > 0.0 and normal.y / length >= min_up


## Files the walkable triangles of `indices` in buckets of `bucket_m` over `bounds`: {dims, start, tris, lowest}, the arrays
## MeshGroundData holds. Ids go in ascending order inside a bucket, so the result is the same on every machine.
static func build_buckets(vertices: PackedVector3Array, indices: PackedInt32Array, bounds: Rect2, bucket_m: float, walkable_deg: float) -> Dictionary:
	var dims := Vector2i(maxi(1, ceili(bounds.size.x / bucket_m)), maxi(1, ceili(bounds.size.y / bucket_m)))
	var min_up := cos(deg_to_rad(walkable_deg))
	var start := PackedInt32Array()
	start.resize(dims.x * dims.y + 1)
	var spans := PackedInt32Array()
	var lowest := INF
	for id: int in range(indices.size() / 3):
		var a := vertices[indices[id * 3]]
		var b := vertices[indices[id * 3 + 1]]
		var c := vertices[indices[id * 3 + 2]]
		if not is_walkable(a, b, c, min_up):
			continue
		var low := (Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))) - bounds.position - Vector2.ONE * BUCKET_MARGIN_M) / bucket_m
		var high := (Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))) - bounds.position + Vector2.ONE * BUCKET_MARGIN_M) / bucket_m
		var x0 := clampi(floori(low.x), 0, dims.x - 1)
		var z0 := clampi(floori(low.y), 0, dims.y - 1)
		var x1 := clampi(floori(high.x), 0, dims.x - 1)
		var z1 := clampi(floori(high.y), 0, dims.y - 1)
		spans.append(id)
		spans.append(x0)
		spans.append(z0)
		spans.append(x1)
		spans.append(z1)
		for bz: int in range(z0, z1 + 1):
			for bx: int in range(x0, x1 + 1):
				start[bz * dims.x + bx + 1] += 1
		lowest = minf(lowest, minf(a.y, minf(b.y, c.y)))
	for i: int in range(1, start.size()):
		start[i] += start[i - 1]
	var fill := start.duplicate()
	var tris := PackedInt32Array()
	tris.resize(start[start.size() - 1])
	for first: int in range(0, spans.size(), 5):
		for bz: int in range(spans[first + 2], spans[first + 4] + 1):
			for bx: int in range(spans[first + 1], spans[first + 3] + 1):
				var bucket := bz * dims.x + bx
				tris[fill[bucket]] = spans[first]
				fill[bucket] += 1
	return {"dims": dims, "start": start, "tris": tris, "lowest": 0.0 if is_inf(lowest) else lowest}


## The bucket under (x, z), -1 off the footprint (a NaN is off it too).
static func _bucket_of(x: float, z: float, data: MeshGroundData) -> int:
	var dims := data.bucket_dims
	var fx := (x - data.bounds.position.x) / data.bucket_m
	var fz := (z - data.bounds.position.y) / data.bucket_m
	if not (fx >= 0.0 and fz >= 0.0 and fx <= dims.x and fz <= dims.y):
		return -1
	return mini(int(fz), dims.y - 1) * dims.x + mini(int(fx), dims.x - 1)


## Height of the plane of triangle (a, b, c) at (x, z); the triangle must not be a wall.
static func _plane_y(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> float:
	var normal := (b - a).cross(c - a)
	return a.y - (normal.x * (x - a.x) + normal.z * (z - a.z)) / normal.y


## Edges count as inside, with either winding.
static func _inside(a: Vector3, b: Vector3, c: Vector3, at: Vector2) -> bool:
	var s0 := (b.x - a.x) * (at.y - a.z) - (b.z - a.z) * (at.x - a.x)
	var s1 := (c.x - b.x) * (at.y - b.z) - (c.z - b.z) * (at.x - b.x)
	var s2 := (a.x - c.x) * (at.y - c.z) - (a.z - c.z) * (at.x - c.x)
	return (s0 >= -EDGE_TOLERANCE and s1 >= -EDGE_TOLERANCE and s2 >= -EDGE_TOLERANCE) \
			or (s0 <= EDGE_TOLERANCE and s1 <= EDGE_TOLERANCE and s2 <= EDGE_TOLERANCE)
