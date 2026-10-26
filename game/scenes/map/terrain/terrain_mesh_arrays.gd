class_name TerrainMeshArrays
extends RefCounted

## The vertex arrays of the map's visible ground, built from its triangles (MapTerrainData): positions, one set of flat
## normals (as the triangles come), one set of smooth normals (summed per lattice vertex, so slopes read as one
## surface), the tile of each vertex in COLOR, the place of the cliff texture on the walls in UV (WallUvRules), and the
## indices. What it does NOT do: hold a mesh node or answer heights.
## Ref: sacmap.d generateNormals, appendEdgeWall.

## The arrays of a Mesh without the normals; `with_normals` completes them.
var arrays := []
var flat_normals := PackedVector3Array()
var smooth_normals := PackedVector3Array()


## `tiles` is the 256x256 tile index of the map (Terrain.tile_ids), empty for tile 0 everywhere.
## Null when `data` is not usable.
static func from_data(data: MapTerrainData, tiles: PackedByteArray) -> TerrainMeshArrays:
	if data == null or not data.is_valid():
		return null
	var land_vertices := data.land_triangles * 3
	var lattice := data.lattice
	var side := TerrainGrid.SIDE
	var colors := PackedColorArray()
	colors.resize(data.vertices.size())
	for first in range(0, data.vertices.size(), 3):
		# The cell of a triangle is the lowest column and row of its corners.
		var column := mini(mini(lattice[first] % side, lattice[first + 1] % side), lattice[first + 2] % side)
		var row := mini(mini(lattice[first] / side, lattice[first + 1] / side), lattice[first + 2] / side)
		var tile := float(0 if tiles.is_empty() else tiles[row * side + column]) / 255.0
		for k in 3:
			# The whole tile over the whole cell (0..1), so a tile meets its neighbour edge to edge; the shader keeps the
			# lookup inside the tile; alpha 0 marks a wall. Ref: sacmap.d:888.
			var at := lattice[first + k]
			colors[first + k] = Color(tile, at % side - column, at / side - row) if first < land_vertices else Color(tile, 0.0, 0.0, 0.0)
	var walls := PackedInt32Array(range(land_vertices, data.indices.size(), 3))
	var built := TerrainMeshArrays.new()
	built.arrays.resize(Mesh.ARRAY_MAX)
	built.arrays[Mesh.ARRAY_VERTEX] = data.vertices
	built.arrays[Mesh.ARRAY_COLOR] = colors
	built.arrays[Mesh.ARRAY_TEX_UV] = _wall_uvs(data.vertices, data.indices, walls)
	built.arrays[Mesh.ARRAY_INDEX] = data.indices
	built.flat_normals = data.normals
	built.smooth_normals = _smooth_normals(data)
	return built


## A copy of the arrays with the normals of `smooth` or the flat ones, ready for `ArrayMesh.add_surface_from_arrays`.
func with_normals(smooth: bool) -> Array:
	var result := arrays.duplicate()
	result[Mesh.ARRAY_NORMAL] = smooth_normals if smooth else flat_normals
	return result


## Each land vertex gets the sum of the unnormalized cross products of the land triangles that share its lattice vertex
## (bigger faces weigh more), normalized. The walls keep their flat normal, so the cliff edge stays sharp.
static func _smooth_normals(data: MapTerrainData) -> PackedVector3Array:
	var sums := PackedVector3Array()
	sums.resize(TerrainGrid.COUNT)
	var vertices := data.vertices
	var lattice := data.lattice
	var land_vertices := data.land_triangles * 3
	for first in range(0, land_vertices, 3):
		var cross := (vertices[first + 1] - vertices[first]).cross(vertices[first + 2] - vertices[first])
		if cross.y < 0.0:
			cross = -cross
		for k in 3:
			sums[lattice[first + k]] += cross
	var result := data.normals.duplicate()
	for id in land_vertices:
		var sum := sums[lattice[id]]
		if sum.length_squared() > 0.0:
			result[id] = sum.normalized()
	return result


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
