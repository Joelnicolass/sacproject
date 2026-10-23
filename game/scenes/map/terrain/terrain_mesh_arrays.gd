class_name TerrainMeshArrays
extends RefCounted

## The vertex arrays of the map's visible ground, built from its raw triangles: positions, one set of flat normals
## (as the data stores them), one set of smooth normals (averaged per grid vertex, so slopes read as one surface), the
## tile of each vertex in COLOR, and the indices. What it does NOT do: hold a mesh node or answer heights.
## Ref: sacmap.d generateNormals, appendEdgeWall.

## The arrays of a Mesh without the normals; `with_normals` completes them.
var arrays := []
var flat_normals := PackedVector3Array()
var smooth_normals := PackedVector3Array()


## `tiles` is the 256x256 tile index of the map (TerrainShape.tile_ids), empty for tile 0 everywhere.
## Null when `data` is not usable.
static func from_data(data: MapTerrainData, tiles: PackedByteArray) -> TerrainMeshArrays:
	if data == null or not data.is_valid():
		return null
	var vertices := data.vertices
	var indices := data.indices
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var walls := 0
	for triangle in range(0, indices.size(), 3):
		var ids := [indices[triangle], indices[triangle + 1], indices[triangle + 2]]
		var corners := [vertices[ids[0]], vertices[ids[1]], vertices[ids[2]]]
		var cell_x := clampi(mini(mini(int(round(corners[0].x / 10.0)), int(round(corners[1].x / 10.0))), int(round(corners[2].x / 10.0))), 0, 255)
		var cell_z := clampi(mini(mini(int(round(corners[0].z / 10.0)), int(round(corners[1].z / 10.0))), int(round(corners[2].z / 10.0))), 0, 255)
		var tile := 0 if tiles.is_empty() else tiles[cell_z * 256 + cell_x]
		if TerrainRules.is_wall(corners[0], corners[1], corners[2]):
			_color_wall(colors, ids, tile, walls % 2 == 0)
			walls += 1
			continue
		for id in ids:
			var local_x := clampf(vertices[id].x / 10.0 - float(cell_x), 0.02, 0.98)
			var local_z := clampf(vertices[id].z / 10.0 - float(cell_z), 0.02, 0.98)
			colors[id] = Color(float(tile) / 255.0, local_x, local_z)
	var built := TerrainMeshArrays.new()
	built.arrays.resize(Mesh.ARRAY_MAX)
	built.arrays[Mesh.ARRAY_VERTEX] = vertices
	built.arrays[Mesh.ARRAY_COLOR] = colors
	built.arrays[Mesh.ARRAY_INDEX] = indices
	built.flat_normals = data.normals
	built.smooth_normals = _smooth_normals(vertices, indices, data.normals)
	return built


## A copy of the arrays with the normals of `smooth` or the flat ones, ready for `ArrayMesh.add_surface_from_arrays`.
func with_normals(smooth: bool) -> Array:
	var result := arrays.duplicate()
	result[Mesh.ARRAY_NORMAL] = smooth_normals if smooth else flat_normals
	return result


## Each ground position gets the sum of the unnormalized cross products of the triangles that touch it (bigger faces
## weigh more), normalized. Walls (no area seen from above) and every vertex a wall touches keep the data normal, so
## the cliff edge stays sharp.
static func _smooth_normals(vertices: PackedVector3Array, indices: PackedInt32Array, flat: PackedVector3Array) -> PackedVector3Array:
	var sums := {}
	var wall_vertex := {}
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		if TerrainRules.is_wall(vertices[a], vertices[b], vertices[c]):
			wall_vertex[a] = true
			wall_vertex[b] = true
			wall_vertex[c] = true
			continue
		var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if cross.y < 0.0:
			cross = -cross
		for id in [a, b, c]:
			var key := _position_key(vertices[id])
			sums[key] = (sums[key] if sums.has(key) else Vector3.ZERO) + cross
	var result := flat.duplicate()
	for id in vertices.size():
		if wall_vertex.has(id):
			continue
		var key := _position_key(vertices[id])
		if sums.has(key) and (sums[key] as Vector3).length_squared() > 0.0:
			result[id] = (sums[key] as Vector3).normalized()
	return result


static func _position_key(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))


## Wall texcoords: top_a (0,0), top_b (1,0), bot_b (1,1), bot_a (0,1); the importer keeps each wall as
## (top_a, bot_b, top_b), (bot_b, top_a, bot_a). Alpha 0 marks the wall for sacrifice_ground.gdshader.
static func _color_wall(colors: PackedColorArray, ids: Array, tile: int, first: bool) -> void:
	var uvs := [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)] if first else [Vector2(1, 1), Vector2(0, 0), Vector2(0, 1)]
	for k in 3:
		colors[ids[k]] = Color(float(tile) / 255.0, uvs[k].x, uvs[k].y, 0.0)
