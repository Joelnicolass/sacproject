class_name TerrainFaces
extends RefCounted

## Turns a map's heights and voids into the triangles of its ground: up to two land triangles per 10 m cell (with one void
## corner the diagonal is picked so the land half stays) and the cliff walls that drop under every rim. Three unshared
## vertices per triangle with its flat normal and the lattice vertex under each, all the land first, the order the game has
## always loaded. Pure and static, in memory only. Not: saving it, the smooth normals of the look (TerrainMeshArrays), the
## per-cell index (TerrainRules), the stamps and holes of a match (GroundField).

## The corners of a cell as lattice id offsets from its low corner: 0 = (x, z), 1 = (x + 1, z), 2 = (x + 1, z + 1), 3 = (x, z + 1).
const CORNER_IDS: Array[int] = [0, 1, TerrainGrid.SIDE + 1, TerrainGrid.SIDE]
## For each mask of land corners (bit k = corner k), the lattice ids (from the low corner, as CORNER_IDS) of its land triangles' corners in
## order: two in a full cell, one when exactly one corner is void (the diagonal so the land half stays), none otherwise.
const LAND_CORNER_IDS: Array[Array] = [
	[],
	[],
	[],
	[],
	[],
	[],
	[],
	[0, 1, TerrainGrid.SIDE + 1],
	[],
	[],
	[],
	[0, 1, TerrainGrid.SIDE],
	[],
	[TerrainGrid.SIDE + 1, TerrainGrid.SIDE, 0],
	[1, TerrainGrid.SIDE + 1, TerrainGrid.SIDE],
	[0, 1, TerrainGrid.SIDE + 1, TerrainGrid.SIDE + 1, TerrainGrid.SIDE, 0],
]
## A side wall of a cell: [top end a, top end b, the two vertices just outside]; it stands when both of those are void.
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
		_add_lands(faces, heights_m, lands)
		faces.land_triangles = faces.indices.size() / 3
		for z in TerrainGrid.SIDE - 1:
			var row := (z + PAD) * PADDED_SIDE + PAD
			for x in TerrainGrid.SIDE - 1:
				var land := lands[z * TerrainGrid.SIDE + x]
				var at := row + x
				# Walls stand on cells with three or four land corners; a full one needs a void just outside a side.
				if (
					land == 15
					and voids[at - PADDED_SIDE] == 0
					and voids[at + 2 * PADDED_SIDE + 1] == 0
					and voids[at + PADDED_SIDE - 1] == 0
					and voids[at + 2] == 0
				):
					continue
				if land == 7 or land >= 11 and land != 12:
					_add_walls(faces, heights_m, voids, land, x, z)
	return faces


## The land triangles of every cell in order, written into arrays sized for them (as MapTerrainData.add, without a call each).
static func _add_lands(
	faces: MapTerrainData, heights_m: PackedFloat32Array, lands: PackedByteArray
) -> void:
	var count := 0
	for land in lands:
		count += LAND_CORNER_IDS[land].size()
	var vertices := PackedVector3Array()
	vertices.resize(count)
	var normals := PackedVector3Array()
	normals.resize(count)
	var lattice := PackedInt32Array()
	lattice.resize(count)
	var indices := PackedInt32Array()
	indices.resize(count)
	var cells := PackedInt32Array()
	cells.resize(count / 3)
	var at := 0
	for cell in lands.size():
		var corners: Array = LAND_CORNER_IDS[lands[cell]]
		for k in corners.size():
			var id: int = cell + corners[k]
			vertices[at + k] = Vector3(
				(id % TerrainGrid.SIDE) * TerrainGrid.CELL_M,
				heights_m[id],
				(id / TerrainGrid.SIDE) * TerrainGrid.CELL_M
			)
			lattice[at + k] = id
			indices[at + k] = at + k
		for first in range(at, at + corners.size(), 3):
			cells[first / 3] = cell
			var right := (vertices[first + 1] - vertices[first]).cross(
				vertices[first + 2] - vertices[first]
			)
			var normal := Vector3.UP if right == Vector3.ZERO else (-right).normalized()
			normals[first] = normal
			normals[first + 1] = normal
			normals[first + 2] = normal
		at += corners.size()
	faces.vertices = vertices
	faces.normals = normals
	faces.lattice = lattice
	faces.indices = indices
	faces.land_cells = cells


## The side walls of a cell with three or four land corners, then the wall across it when exactly one corner is void.
static func _add_walls(
	faces: MapTerrainData,
	heights_m: PackedFloat32Array,
	voids: PackedByteArray,
	land: int,
	x: int,
	z: int
) -> void:
	var padded := (z + PAD) * PADDED_SIDE + x + PAD
	for side in SIDE_WALLS:
		var a: int = side[0]
		var b: int = side[1]
		var out_a: Vector2i = side[2]
		var out_b: Vector2i = side[3]
		if (
			voids[padded + out_a.y * PADDED_SIDE + out_a.x] != 0
			and voids[padded + out_b.y * PADDED_SIDE + out_b.x] != 0
			and land & (1 << a)
			and land & (1 << b)
		):
			_add_wall(faces, heights_m, x, z, a, b)
	if land != 15:
		var gone := 0
		while land & (1 << gone):
			gone += 1
		_add_wall(faces, heights_m, x, z, (gone + 3) % 4, (gone + 1) % 4)


## A strip that drops HoleWallRules.DEPTH_M under the rim from corner a to corner b, as two triangles.
static func _add_wall(
	faces: MapTerrainData, heights_m: PackedFloat32Array, x: int, z: int, a: int, b: int
) -> void:
	var id_a := z * TerrainGrid.SIDE + x + CORNER_IDS[a]
	var id_b := z * TerrainGrid.SIDE + x + CORNER_IDS[b]
	var top_a := Vector3(
		(id_a % TerrainGrid.SIDE) * TerrainGrid.CELL_M,
		heights_m[id_a],
		(id_a / TerrainGrid.SIDE) * TerrainGrid.CELL_M
	)
	var top_b := Vector3(
		(id_b % TerrainGrid.SIDE) * TerrainGrid.CELL_M,
		heights_m[id_b],
		(id_b / TerrainGrid.SIDE) * TerrainGrid.CELL_M
	)
	var down := Vector3(0.0, -HoleWallRules.DEPTH_M, 0.0)
	faces.add(top_a, top_b + down, top_b, id_a, id_b, id_b, true)
	faces.add(top_b + down, top_a, top_a + down, id_b, id_a, id_a, true)


## One byte per cell (z * SIDE + x): bit k set when corner k of the cell is land (0 for the last row and column).
static func _land_corners(voids: PackedByteArray) -> PackedByteArray:
	var lands := PackedByteArray()
	lands.resize(TerrainGrid.SIDE * TerrainGrid.SIDE)
	for z in TerrainGrid.SIDE - 1:
		var low := (z + PAD) * PADDED_SIDE + PAD
		var high := low + PADDED_SIDE
		for x in TerrainGrid.SIDE - 1:
			lands[z * TerrainGrid.SIDE + x] = (
				(1 if voids[low + x] == 0 else 0)
				| (2 if voids[low + x + 1] == 0 else 0)
				| (4 if voids[high + x + 1] == 0 else 0)
				| (8 if voids[high + x] == 0 else 0)
			)
	return lands


## The void mask with a frame of `PAD` void vertices around it (whole rows copied at once).
static func _padded_voids(void_mask: PackedByteArray) -> PackedByteArray:
	var side := PackedByteArray()
	side.resize(PAD)
	side.fill(1)
	var frame := PackedByteArray()
	frame.resize(PAD * PADDED_SIDE)
	frame.fill(1)
	var padded := frame.duplicate()
	for z in TerrainGrid.SIDE:
		padded.append_array(side)
		padded.append_array(void_mask.slice(z * TerrainGrid.SIDE, (z + 1) * TerrainGrid.SIDE))
		padded.append_array(side)
	padded.append_array(frame)
	return padded
