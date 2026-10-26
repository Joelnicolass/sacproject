class_name TerrainFaces
extends RefCounted

## Turns a map's heights and voids into the triangles of its ground: up to two land triangles per 10 m cell (with one
## void corner the diagonal is picked so the land half stays) and the cliff walls that drop under every rim. Three
## unshared vertices per triangle with its flat normal and the lattice vertex under each, all the land first and the
## walls after, the order the game has always loaded. Pure and static; the result lives in memory only. Not: saving it,
## the smooth normals of the look (TerrainMeshArrays), the per-cell index (TerrainRules), the stamps and holes of a
## match (GroundField).
## Ref: hntr(), get_faces() and edge_wall_exists() of tools/import/sac_formats/terrain.py up to 22edea77 (FACES PARITY
## PASS against the triangles it wrote, on the 7 maps of the original).

## The corners of a cell as lattice offsets: 0 = (x, z), 1 = (x + 1, z), 2 = (x + 1, z + 1), 3 = (x, z + 1).
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
## The same corners as lattice id offsets from the cell's low corner.
const CORNER_IDS: Array[int] = [0, 1, TerrainGrid.SIDE + 1, TerrainGrid.SIDE]
## A wall along a side of the cell, in slot order: [top end a, top end b, the two lattice vertices just outside that
## side]. It stands when a and b are land, a third corner is land, and both outside vertices are void (or off the map).
const SIDE_WALLS: Array[Array] = [
	[0, 1, Vector2i(0, -1), Vector2i(1, -1)],
	[2, 3, Vector2i(1, 2), Vector2i(0, 2)],
	[3, 0, Vector2i(-1, 1), Vector2i(-1, 0)],
	[1, 2, Vector2i(2, 0), Vector2i(2, 1)],
]
## Lattice vertices of void added around the map, so the outside-of-side test never leaves the array.
const PAD := 2
const PADDED_SIDE := TerrainGrid.SIDE + 2 * PAD


## The ground of `heights` as triangles (see the class doc). Empty when `heights` is missing or not valid.
static func build(heights: TerrainHeights) -> MapTerrainData:
	var faces := MapTerrainData.new()
	if heights != null and heights.is_valid():
		var heights_m := heights.heights_m
		var voids := _padded_voids(heights.void_mask)
		var lands := _land_corners(voids)
		var cells := TerrainGrid.SIDE - 1
		for z in cells:
			for x in cells:
				_add_land(faces, heights_m, lands[z * TerrainGrid.SIDE + x], x, z)
		faces.land_triangles = faces.indices.size() / 3
		for z in cells:
			for x in cells:
				_add_walls(faces, heights_m, voids, lands[z * TerrainGrid.SIDE + x], x, z)
	return faces


## The two land triangles of a full cell, one when exactly one corner is void, none otherwise (`land`: corner bits).
static func _add_land(faces: MapTerrainData, heights_m: PackedFloat32Array, land: int, x: int, z: int) -> void:
	if land & 1:
		if (land & 6) == 6:
			_add_triangle(faces, heights_m, x, z, 0, 1, 2)
	elif (land & 14) == 14:
		_add_triangle(faces, heights_m, x, z, 1, 2, 3)
	if land & 4:
		if (land & 9) == 9:
			_add_triangle(faces, heights_m, x, z, 2, 3, 0)
	elif (land & 11) == 11:
		_add_triangle(faces, heights_m, x, z, 0, 1, 3)


## The side walls of a cell on the rim, then the wall across it when exactly one corner is void.
static func _add_walls(faces: MapTerrainData, heights_m: PackedFloat32Array, voids: PackedByteArray, land: int, x: int, z: int) -> void:
	var count := (land & 1) + ((land >> 1) & 1) + ((land >> 2) & 1) + ((land >> 3) & 1)
	if count < 3:
		return
	for side in SIDE_WALLS:
		var a: int = side[0]
		var b: int = side[1]
		var out_a: Vector2i = side[2]
		var out_b: Vector2i = side[3]
		if land & (1 << a) and land & (1 << b) and _is_void(voids, x + out_a.x, z + out_a.y) \
				and _is_void(voids, x + out_b.x, z + out_b.y):
			_add_wall(faces, heights_m, x, z, a, b)
	if count == 3:
		var gone := 0
		while land & (1 << gone):
			gone += 1
		_add_wall(faces, heights_m, x, z, (gone + 3) % 4, (gone + 1) % 4)


## A strip that drops HoleWallRules.DEPTH_M under the rim from corner a to corner b, as two triangles.
static func _add_wall(faces: MapTerrainData, heights_m: PackedFloat32Array, x: int, z: int, a: int, b: int) -> void:
	var id_a := z * TerrainGrid.SIDE + x + CORNER_IDS[a]
	var id_b := z * TerrainGrid.SIDE + x + CORNER_IDS[b]
	var top_a := _point(heights_m, id_a)
	var top_b := _point(heights_m, id_b)
	var down := Vector3(0.0, -HoleWallRules.DEPTH_M, 0.0)
	faces.add(top_a, top_b + down, top_b, id_a, id_b, id_b, true)
	faces.add(top_b + down, top_a, top_a + down, id_b, id_a, id_a, true)


static func _add_triangle(faces: MapTerrainData, heights_m: PackedFloat32Array, x: int, z: int, a: int, b: int, c: int) -> void:
	var cell := z * TerrainGrid.SIDE + x
	var id_a := cell + CORNER_IDS[a]
	var id_b := cell + CORNER_IDS[b]
	var id_c := cell + CORNER_IDS[c]
	faces.add(_point(heights_m, id_a), _point(heights_m, id_b), _point(heights_m, id_c), id_a, id_b, id_c, false)


## The lattice vertex `id` as a point in metres, at its height.
static func _point(heights_m: PackedFloat32Array, id: int) -> Vector3:
	return Vector3((id % TerrainGrid.SIDE) * TerrainGrid.CELL_M, heights_m[id], (id / TerrainGrid.SIDE) * TerrainGrid.CELL_M)


## One byte per cell (z * SIDE + x): bit k set when corner k of the cell is land.
static func _land_corners(voids: PackedByteArray) -> PackedByteArray:
	var lands := PackedByteArray()
	lands.resize(TerrainGrid.SIDE * TerrainGrid.SIDE)
	for z in TerrainGrid.SIDE - 1:
		for x in TerrainGrid.SIDE - 1:
			var land := 0
			for corner in 4:
				if not _is_void(voids, x + CORNERS[corner].x, z + CORNERS[corner].y):
					land |= 1 << corner
			lands[z * TerrainGrid.SIDE + x] = land
	return lands


static func _is_void(voids: PackedByteArray, x: int, z: int) -> bool:
	return voids[(z + PAD) * PADDED_SIDE + x + PAD] != 0


## The void mask with a frame of `PAD` void vertices around it.
static func _padded_voids(void_mask: PackedByteArray) -> PackedByteArray:
	var padded := PackedByteArray()
	padded.resize(PADDED_SIDE * PADDED_SIDE)
	padded.fill(1)
	for z in TerrainGrid.SIDE:
		for x in TerrainGrid.SIDE:
			padded[(z + PAD) * PADDED_SIDE + x + PAD] = void_mask[z * TerrainGrid.SIDE + x]
	return padded

