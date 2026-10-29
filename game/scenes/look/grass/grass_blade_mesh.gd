class_name GrassBladeMesh
extends RefCounted

## The mesh of one blade, built once per quality preset (never saved). Opaque triangles, no alpha:
## `segments` rows of two vertices and a tip, so 1 = 3 vertices, 2 = 5, 3 = 7.
## Local space: x = side (width 1 at the root, tapering to the tip), y = 0..1 along the blade.
## UV = (side 0..1, height 0..1). The shader scales, bends and places it.


static func build(segments: int, width_scale := 1.0) -> ArrayMesh:
	var rows := maxi(segments, 1)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in rows:
		var t := float(row) / float(rows)
		var half := 0.5 * (1.0 - 0.93 * pow(t, 0.9)) * width_scale
		vertices.append(Vector3(-half, t, 0.0))
		vertices.append(Vector3(half, t, 0.0))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
	vertices.append(Vector3(0.0, 1.0, 0.0))
	uvs.append(Vector2(0.5, 1.0))
	for row in rows - 1:
		var i := row * 2
		indices.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	var last := (rows - 1) * 2
	indices.append_array([last, last + 1, rows * 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3(0, 0, 1))
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## `count` instances of one cell: offsets in a `cell_m` square from a low-discrepancy sequence, so
## any prefix of the list is evenly spread (the far cells use a prefix: same blades, fewer of
## them). Per instance: the translation, and custom data = (yaw, height, lean, rank 0..1).
## Returns the raw MultiMesh buffer (12 transform + 4 custom floats per instance).
static func instance_buffer(count: int, cell_m: float, seed_value: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(count * 16)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a1 := 0.7548776662466927
	var a2 := 0.5698402909980532
	var span := cell_m * 0.9999
	for i in count:
		var at := i * 16
		var x := fmod(0.5 + a1 * float(i + 1), 1.0) * span
		var z := fmod(0.5 + a2 * float(i + 1), 1.0) * span
		buffer[at] = 1.0
		buffer[at + 3] = x
		buffer[at + 5] = 1.0
		buffer[at + 7] = 0.0
		buffer[at + 10] = 1.0
		buffer[at + 11] = z
		buffer[at + 12] = rng.randf()
		buffer[at + 13] = rng.randf()
		buffer[at + 14] = rng.randf()
		buffer[at + 15] = (float(i) + 0.5) / float(count)
	return buffer
