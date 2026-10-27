class_name HoleWallRules
extends RefCounted

## The walls around the holes the ground has now: along every edge where land meets a triangle that lost a corner, a vertical
## strip drops `DEPTH_M` below the land, with the cliff texture, so a hole shows a pit and not the sky under the map. Pure
## and static (the arrays of a mesh, no node): HoleWalls draws them. The walls of the file's own holes are already in the
## map's mesh; these are only the ones that are new. The strips are at the heights of the FILE: the ground shader moves them
## with the rest of the vertices.
## Ref: sacengine appendEdgeWall, dynamicEdgeMesh (sacmap.d:343-366, 780-813).

## How far a wall goes down.
## Ref: sacengine mapDepth.
const DEPTH_M := 50.0


## The arrays (positions, normals, COLOR, indices, UV) of the walls for `removed` vertex ids, ready for ArrayMesh. Empty when
## none. COLOR alpha 0 marks a wall for the ground shader; UV places the cliff texture (WallUvRules).
static func arrays(index: TerrainRules.Index, removed: PackedInt32Array) -> Array:
	var edges := boundary(index, removed)
	if edges.is_empty():
		return []
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var down := Vector3(0.0, -DEPTH_M, 0.0)
	var ends := PackedVector2Array()
	for edge: Array in edges:
		ends.append_array([Vector2(edge[0].x, edge[0].z), Vector2(edge[1].x, edge[1].z)])
	var metres := WallUvRules.rim_metres(ends)
	for w in edges.size():
		var a: Vector3 = edges[w][0]
		var b: Vector3 = edges[w][1]
		var first := vertices.size()
		vertices.append_array([a, b, b + down, a + down])
		normals.append_array([edges[w][2], edges[w][2], edges[w][2], edges[w][2]])
		colors.append_array([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
		uvs.append_array([Vector2(metres[w * 2], 0.0), Vector2(metres[w * 2 + 1], 0.0), Vector2(metres[w * 2 + 1], 1.0), Vector2(metres[w * 2], 1.0)])
		indices.append_array([first, first + 2, first + 1, first + 2, first, first + 3])
	return [vertices, normals, colors, indices, uvs]


## The edges between a land triangle and one that lost a corner, each as [from, to, normal toward the hole] (positions of the file).
static func boundary(index: TerrainRules.Index, removed: PackedInt32Array) -> Array:
	var gone := {}
	for id in removed:
		gone[id] = true
	var seen := {}
	for id in removed:
		var vertex := TerrainGrid.vertex_of(id)
		for dz in range(-2, 2):
			for dx in range(-2, 2):
				var cell := vertex + Vector2i(dx, dz)
				if cell.x < 0 or cell.y < 0 or cell.x >= TerrainGrid.SIDE or cell.y >= TerrainGrid.SIDE:
					continue
				for k in 2:
					var triangle := index.cells[TerrainGrid.id_of(cell) * 2 + k]
					if triangle >= 0:
						seen[triangle] = true
	var sides := {}
	for triangle: int in seen:
		for corner in 3:
			var from := index.corners[triangle * 3 + corner]
			var to := index.corners[triangle * 3 + (corner + 1) % 3]
			var key := mini(from, to) * TerrainGrid.COUNT + maxi(from, to)
			if not sides.has(key):
				sides[key] = []
			(sides[key] as Array).append([triangle, corner])
	var found := []
	for key: int in sides:
		var pair: Array = sides[key]
		if pair.size() != 2:
			continue
		var first_lost := _lost(index, gone, pair[0][0])
		if first_lost == _lost(index, gone, pair[1][0]):
			continue
		var land: Array = pair[1] if first_lost else pair[0]
		var hole: Array = pair[0] if first_lost else pair[1]
		found.append(_wall(index, land, hole[0]))
	return found


## True when a corner of `triangle` was taken away.
static func _lost(index: TerrainRules.Index, gone: Dictionary, triangle: int) -> bool:
	return gone.has(index.corners[triangle * 3]) or gone.has(index.corners[triangle * 3 + 1]) or gone.has(index.corners[triangle * 3 + 2])


## [from, to, normal] of the side of `land` ([triangle, corner]) that faces the lost triangle `hole`.
static func _wall(index: TerrainRules.Index, land: Array, hole: int) -> Array:
	var a := index.ground[land[0] * 3 + land[1]]
	var b := index.ground[land[0] * 3 + (land[1] + 1) % 3]
	var along := (b - a)
	along.y = 0.0
	var normal := Vector3(along.z, 0.0, -along.x).normalized()
	var middle := (index.ground[hole * 3] + index.ground[hole * 3 + 1] + index.ground[hole * 3 + 2]) / 3.0 - (a + b) * 0.5
	if normal.dot(middle) < 0.0:
		normal = -normal
	return [a, b, normal]
