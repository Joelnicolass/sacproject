@tool
class_name GrassBlades
extends RefCounted

## The meshes a field draws. All its blades come from one sequence of points spread evenly over a
## cell (an R2 low-discrepancy sequence): every prefix of it is even too. A tier holds the first
## blades of the sequence, so a tier with fewer is a prefix of one with more, and the shader thins
## any of them by each blade's rank (its place in the sequence) with no pop. With several kinds of
## blade, each point belongs to one kind by a fixed roll on the kinds' weights, so each kind is a
## prefix of its own share; a kind that grows by a map has points of its own (the same sequence,
## shifted), as many as its share, so it adds to the others where it grows. Every instance carries
## its rank and its mesh's segments (custom data). The kit's blade spans x in [-0.5, 0.5] (its
## width) and y in [0, 1] (along it); the shader gives it size, place, curve and colour.

## R2 sequence constants (the plastic number), for points that stay even at any prefix.
const _A1 := 0.7548776662466927
const _A2 := 0.5698402909980532


## `count` points over a square of side `size`, every prefix spread evenly. Another `start` shifts
## the whole pattern (a kind of its own among the others).
static func points(count: int, size: float, start := Vector2(0.5, 0.5)) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		out[i] = Vector2(fposmod(start.x + _A1 * i, 1.0), fposmod(start.y + _A2 * i, 1.0)) * size
	return out


## The kind of each of `count` points, rolled on `weights` (the same every time).
static func kinds_of(count: int, weights: PackedFloat32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(count)
	var total := 0.0
	for weight in weights:
		total += weight
	for i in count:
		# A fixed integer hash of the index: kinds mix evenly along the sequence, the same on every
		# machine.
		var h := (i * 747796405 + 2891336453) & 0xFFFFFFFF
		h = ((h >> ((h >> 28) + 4)) ^ h) * 277803737 & 0xFFFFFFFF
		h = (h >> 22) ^ h
		var roll := float(h) / 4294967296.0 * total
		var kind := 0
		while kind < weights.size() - 1 and roll >= weights[kind]:
			roll -= weights[kind]
			kind += 1
		out[i] = kind
	return out


## The MultiMesh buffer of the points of `all` below `count` that are of `kind` (all of them with
## `kinds` empty): per blade a move to its point (12 floats, rows of the basis with the origin last)
## and its custom data (rank in the whole sequence, the mesh's segments).
static func instance_buffer(
	all: PackedVector2Array, count: int, kinds := PackedInt32Array(), kind := 0, segments := 1
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var base := float(all.size())
	for i in count:
		if not kinds.is_empty() and kinds[i] != kind:
			continue
		var at := out.size()
		out.resize(at + 16)
		out[at] = 1.0
		out[at + 3] = all[i].x
		out[at + 5] = 1.0
		out[at + 10] = 1.0
		out[at + 11] = all[i].y
		out[at + 12] = (i + 0.5) / base
		out[at + 13] = segments
	return out


## The kit's blade of `segments` segments: two vertices a row and one at the tip. UV x across it,
## y from the tip (0) to the root (1), so a texture can be laid on it.
static func blade_mesh(segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in segments:
		var t := float(row) / segments
		vertices.append(Vector3(-0.5, t, 0.0))
		vertices.append(Vector3(0.5, t, 0.0))
		uvs.append(Vector2(0.0, 1.0 - t))
		uvs.append(Vector2(1.0, 1.0 - t))
	vertices.append(Vector3(0.0, 1.0, 0.0))
	uvs.append(Vector2(0.5, 0.0))
	for row in segments - 1:
		var a := row * 2
		indices.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var last := (segments - 1) * 2
	indices.append_array([last, vertices.size() - 1, last + 1])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## For each kind of `kinds`, one MultiMesh per tier of `quality`: tier k holds that kind's blades
## among the first `blades_in_tier(k)` points. The kit's blade has fewer segments the farther the
## tier; a kind's own mesh is the same in every tier.
static func tier_meshes(quality: GrassQuality, kinds: Array[GrassMesh]) -> Array[Array]:
	var all := points(quality.blades_per_cell(), quality.cell_size)
	# The kinds that share the points, by weight; the ones that grow by a map have their own.
	var weights := PackedFloat32Array()
	var shared: Dictionary[int, int] = {}
	var shared_total := 0.0
	for index in kinds.size():
		if not kinds[index].grows_by_map():
			shared[index] = weights.size()
			weights.append(kinds[index].weight)
			shared_total += kinds[index].weight
	var rolled := kinds_of(all.size(), weights) if weights.size() > 1 else PackedInt32Array()
	var blades: Dictionary[int, ArrayMesh] = {}
	var out: Array[Array] = []
	for index in kinds.size():
		var per_tier: Array[MultiMesh] = []
		var own := all
		var share := 1.0
		if not shared.has(index):
			share = kinds[index].weight / shared_total if shared_total > 0.0 else 1.0
			var start := Vector2(fposmod(0.21 + 0.37 * index, 1.0), fposmod(0.83 + 0.29 * index, 1.0))
			own = points(ceili(all.size() * share), quality.cell_size, start)
		for tier in quality.tiers:
			var segments := quality.segments_in_tier(tier)
			var mesh := MultiMesh.new()
			mesh.transform_format = MultiMesh.TRANSFORM_3D
			mesh.use_custom_data = true
			if kinds[index].mesh != null:
				mesh.mesh = kinds[index].mesh
				segments = 0
			else:
				if not blades.has(segments):
					blades[segments] = blade_mesh(segments)
				mesh.mesh = blades[segments]
			var data: PackedFloat32Array
			if shared.has(index):
				var count := quality.blades_in_tier(tier)
				data = instance_buffer(all, count, rolled, shared[index], segments)
			else:
				var count := mini(ceili(quality.blades_in_tier(tier) * share), own.size())
				data = instance_buffer(own, count, PackedInt32Array(), 0, segments)
			mesh.instance_count = data.size() / 16
			if mesh.instance_count > 0:
				mesh.buffer = data
			per_tier.append(mesh)
		out.append(per_tier)
	return out
