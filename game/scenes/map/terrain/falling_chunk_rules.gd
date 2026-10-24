class_name FallingChunkRules
extends RefCounted

## The shape of the piece of ground that drops when a vertex is taken away: the land triangles that touched the vertex (heights
## with the shift the ground had), painted with their own tile, plus a skirt of cliff hanging from the edges that border the
## rest of the land. Pure and static (the arrays of a mesh): FallingChunk draws and drops it. It does not remove the vertex.
## Ref: sacengine makeFallingLandChunkMesh (sacmap.d:388-480).

## How far the skirt hangs (sacengine mapDepth).
const SKIRT_M := 50.0


## The arrays (positions, normals, COLOR, indices) of the piece around lattice vertex `id`; [] when the vertex touches no land.
static func arrays(index: TerrainRules.Index, texels: PackedFloat32Array, tiles: PackedByteArray, id: int) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var sides := {}
	var middle := Vector3.ZERO
	var count := 0
	for cell_row in [id / TerrainRules.GRID - 1, id / TerrainRules.GRID]:
		for cell_column in [id % TerrainRules.GRID - 1, id % TerrainRules.GRID]:
			if cell_row < 0 or cell_column < 0 or cell_row >= TerrainRules.GRID or cell_column >= TerrainRules.GRID:
				continue
			var cell: int = cell_row * TerrainRules.GRID + cell_column
			for k in 2:
				var triangle := index.cells[cell * 2 + k]
				if triangle < 0 or not _touches(index, triangle, id):
					continue
				var tile := 0 if tiles.is_empty() else tiles[cell]
				var corners: Array[Vector3] = []
				for corner in 3:
					var at := index.ground[triangle * 3 + corner]
					at.y += texels[index.corners[triangle * 3 + corner] * 2]
					corners.append(at)
					middle += at
					count += 1
					indices.append(vertices.size())
					vertices.append(at)
					var inside := Vector2(at.x / TerrainRules.CELL - float(cell_column), at.z / TerrainRules.CELL - float(cell_row))
					colors.append(Color(float(tile) / 255.0, clampf(inside.x, 0.0, 1.0), clampf(inside.y, 0.0, 1.0)))
					normals.append(Vector3.UP)
				for corner in 3:
					var from := index.corners[triangle * 3 + corner]
					var to := index.corners[triangle * 3 + (corner + 1) % 3]
					var key := Vector2i(mini(from, to), maxi(from, to))
					sides[key] = [corners[corner], corners[(corner + 1) % 3], int((sides[key] as Array)[2]) + 1 if sides.has(key) else 1]
	if vertices.is_empty():
		return []
	_skirt(sides, middle / float(count), vertices, normals, colors, indices)
	return [vertices, normals, null, colors, null, null, null, null, null, null, null, null, indices]


static func _touches(index: TerrainRules.Index, triangle: int, id: int) -> bool:
	return index.corners[triangle * 3] == id or index.corners[triangle * 3 + 1] == id or index.corners[triangle * 3 + 2] == id


## A hanging wall under every side only one triangle of the piece has (the rest of the land is on its other side).
static func _skirt(sides: Dictionary, middle: Vector3, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var down := Vector3(0.0, -SKIRT_M, 0.0)
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for key: Vector2i in sides:
		var side: Array = sides[key]
		if int(side[2]) != 1:
			continue
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var along := b - a
		var normal := Vector3(along.z, 0.0, -along.x).normalized()
		if normal.dot((a + b) * 0.5 - middle) < 0.0:
			normal = -normal
		var first := vertices.size()
		vertices.append_array([a, b, b + down, a + down])
		for uv: Vector2 in uvs:
			normals.append(normal)
			colors.append(Color(0.0, uv.x, uv.y, 0.0))
		indices.append_array([first, first + 2, first + 1, first + 2, first, first + 3])
