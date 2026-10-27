class_name FallingChunkRules
extends RefCounted

## The shape of the piece of ground that drops when a vertex is taken away: the land triangles that touched the vertex (heights
## with the shift the ground had), plus a skirt of cliff hanging from the edges that border the
## rest of the land. Pure and static (the arrays of a mesh): FallingChunk draws and drops it. It does not remove the vertex.
## Ref: sacengine makeFallingLandChunkMesh (sacmap.d:388-480).

## How far the skirt hangs.
## Ref: sacengine mapDepth.
const SKIRT_M := 50.0


## The arrays (positions, normals, COLOR, UV, indices) of the piece around lattice vertex `id`; [] when the vertex touches no land.
static func arrays(index: TerrainRules.Index, texels: PackedFloat32Array, id: int) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sides := {}
	var middle := Vector3.ZERO
	var count := 0
	var vertex := TerrainGrid.vertex_of(id)
	for cell_row in [vertex.y - 1, vertex.y]:
		for cell_column in [vertex.x - 1, vertex.x]:
			if cell_row < 0 or cell_column < 0 or cell_row >= TerrainGrid.SIDE or cell_column >= TerrainGrid.SIDE:
				continue
			var cell := TerrainGrid.id_of(Vector2i(cell_column, cell_row))
			for k in 2:
				var triangle := index.cells[cell * 2 + k]
				if triangle < 0 or not _touches(index, triangle, id):
					continue
				var corners: Array[Vector3] = []
				for corner in 3:
					var at := index.ground[triangle * 3 + corner]
					at.y += texels[index.corners[triangle * 3 + corner] * 2]
					corners.append(at)
					middle += at
					count += 1
					indices.append(vertices.size())
					vertices.append(at)
					colors.append(Color.WHITE)
					normals.append(Vector3.UP)
					uvs.append(Vector2.ZERO)
				for corner in 3:
					var from := index.corners[triangle * 3 + corner]
					var to := index.corners[triangle * 3 + (corner + 1) % 3]
					var key := Vector2i(mini(from, to), maxi(from, to))
					sides[key] = [corners[corner], corners[(corner + 1) % 3], int((sides[key] as Array)[2]) + 1 if sides.has(key) else 1]
	if vertices.is_empty():
		return []
	_skirt(sides, middle / float(count), vertices, normals, colors, uvs, indices)
	return [vertices, normals, null, colors, uvs, null, null, null, null, null, null, null, indices]


static func _touches(index: TerrainRules.Index, triangle: int, id: int) -> bool:
	return index.corners[triangle * 3] == id or index.corners[triangle * 3 + 1] == id or index.corners[triangle * 3 + 2] == id


## A hanging wall under every side only one triangle of the piece has (the rest of the land is on its other side).
static func _skirt(sides: Dictionary, middle: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var down := Vector3(0.0, -SKIRT_M, 0.0)
	var hanging: Array = []
	var ends := PackedVector2Array()
	for key: Vector2i in sides:
		if int((sides[key] as Array)[2]) == 1:
			hanging.append(sides[key])
			ends.append_array([Vector2(sides[key][0].x, sides[key][0].z), Vector2(sides[key][1].x, sides[key][1].z)])
	var metres := WallUvRules.rim_metres(ends)
	for w in hanging.size():
		var side: Array = hanging[w]
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var along := b - a
		var normal := Vector3(along.z, 0.0, -along.x).normalized()
		if normal.dot((a + b) * 0.5 - middle) < 0.0:
			normal = -normal
		var first := vertices.size()
		vertices.append_array([a, b, b + down, a + down])
		for k in 4:
			normals.append(normal)
			colors.append(Color(0.0, 0.0, 0.0, 0.0))
		uvs.append_array([Vector2(metres[w * 2], 0.0), Vector2(metres[w * 2 + 1], 0.0), Vector2(metres[w * 2 + 1], 1.0), Vector2(metres[w * 2], 1.0)])
		indices.append_array([first, first + 2, first + 1, first + 2, first, first + 3])
