class_name TerrainMeshArrays
extends RefCounted

## The vertex arrays of the map's visible ground, built from its raw triangles: positions, one set of flat normals
## (as the data stores them), one set of smooth normals (averaged per grid vertex, so slopes read as one surface), the
## tile of each vertex in COLOR, the place of the cliff texture on the walls in UV (WallUvRules), and the indices.
## What it does NOT do: hold a mesh node or answer heights.
## Ref: sacmap.d generateNormals, appendEdgeWall.

## Bumped when the arrays change shape: an imported terrain.glb mesh of an older version is rebuilt (TerrainMesh).
const VERSION := 2

## The arrays of a Mesh without the normals; `with_normals` completes them.
var arrays := []
var flat_normals := PackedVector3Array()
var smooth_normals := PackedVector3Array()


## `tiles` is the 256x256 tile index of the map (Terrain.tile_ids), empty for tile 0 everywhere.
## Null when `data` is not usable.
static func from_data(data: MapTerrainData, tiles: PackedByteArray) -> TerrainMeshArrays:
	if data == null or not data.is_valid():
		return null
	var vertices := data.vertices
	var indices := data.indices
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var walls := PackedInt32Array()
	for triangle in range(0, indices.size(), 3):
		var ids := [indices[triangle], indices[triangle + 1], indices[triangle + 2]]
		var corners := [vertices[ids[0]], vertices[ids[1]], vertices[ids[2]]]
		var cell_x := clampi(mini(mini(int(round(corners[0].x / TerrainGrid.CELL_M)), int(round(corners[1].x / TerrainGrid.CELL_M))), int(round(corners[2].x / TerrainGrid.CELL_M))), 0, TerrainGrid.SIDE - 1)
		var cell_z := clampi(mini(mini(int(round(corners[0].z / TerrainGrid.CELL_M)), int(round(corners[1].z / TerrainGrid.CELL_M))), int(round(corners[2].z / TerrainGrid.CELL_M))), 0, TerrainGrid.SIDE - 1)
		var tile := 0 if tiles.is_empty() else tiles[TerrainGrid.id_of(Vector2i(cell_x, cell_z))]
		if TerrainRules.is_wall(corners[0], corners[1], corners[2]):
			for id in ids:
				colors[id] = Color(float(tile) / 255.0, 0.0, 0.0, 0.0)  # alpha 0 marks a wall for the ground shader
			walls.append(triangle)
			continue
		# The whole tile over the whole cell (0..1), so a tile meets its neighbour edge to edge; the shader keeps the
		# lookup inside the tile. Ref: sacmap.d:888.
		for id in ids:
			var local_x := clampf(vertices[id].x / TerrainGrid.CELL_M - float(cell_x), 0.0, 1.0)
			var local_z := clampf(vertices[id].z / TerrainGrid.CELL_M - float(cell_z), 0.0, 1.0)
			colors[id] = Color(float(tile) / 255.0, local_x, local_z)
	var built := TerrainMeshArrays.new()
	built.arrays.resize(Mesh.ARRAY_MAX)
	built.arrays[Mesh.ARRAY_VERTEX] = vertices
	built.arrays[Mesh.ARRAY_COLOR] = colors
	built.arrays[Mesh.ARRAY_TEX_UV] = _wall_uvs(vertices, indices, walls)
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


## UV of every vertex: on a wall, x = metres along the rim and y = 0 at the rim, 1 at the foot; (0, 0) on the land.
## A wall is two triangles over the same two rim points (x, z); its top vertex at a point is the higher of the two there.
static func _wall_uvs(vertices: PackedVector3Array, indices: PackedInt32Array, walls: PackedInt32Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	var segment_at := {}
	var ends := PackedVector2Array()
	var tops := PackedFloat32Array()
	var segments := PackedInt32Array()
	for triangle in walls:
		var points: Array[Vector2] = []
		for k in 3:
			var at := Vector2(vertices[indices[triangle + k]].x, vertices[indices[triangle + k]].z)
			if points.is_empty() or not (points[0].is_equal_approx(at) or points[-1].is_equal_approx(at)):
				points.append(at)
		var key := [WallUvRules.point_key(points[0]), WallUvRules.point_key(points[-1])]
		key.sort()
		if not segment_at.has(key):
			segment_at[key] = ends.size() / 2
			ends.append_array([points[0], points[-1]])
			tops.append_array([-INF, -INF])
		var segment: int = segment_at[key]
		segments.append(segment)
		for k in 3:
			var end := _end_of(ends, segment, vertices[indices[triangle + k]])
			tops[end] = maxf(tops[end], vertices[indices[triangle + k]].y)
	var metres := WallUvRules.rim_metres(ends)
	for w in walls.size():
		for k in 3:
			var id := indices[walls[w] + k]
			var end := _end_of(ends, segments[w], vertices[id])
			uvs[id] = Vector2(metres[end], 0.0 if vertices[id].y > tops[end] - 1.0 else 1.0)
	return uvs


static func _end_of(ends: PackedVector2Array, segment: int, at: Vector3) -> int:
	return segment * 2 if ends[segment * 2].is_equal_approx(Vector2(at.x, at.z)) else segment * 2 + 1
