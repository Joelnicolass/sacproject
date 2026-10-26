class_name TerrainFaces
extends RefCounted

## Turns a map's heights and voids into the triangles of its ground: up to two land triangles per 10 m cell (with one
## void corner the diagonal is picked so the land half stays) and the cliff walls that drop under every rim. Three
## unshared vertices per triangle with its flat normal, all the land first and the walls after, the order the game has
## always loaded. Pure and static; the result lives in memory only. Not: saving it, the smooth normals of the look
## (TerrainMeshArrays), the per-cell index (TerrainRules), the stamps and holes of a match (GroundField).
## Ref: tools/import/sac_formats/terrain.py hntr(), get_faces(), edge_wall_exists(), slot_ends().

## The corners of a cell as lattice offsets: 0 = (x, z), 1 = (x + 1, z), 2 = (x + 1, z + 1), 3 = (x, z + 1).
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
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
	var soup := _Soup.new()
	if heights != null and heights.is_valid():
		var voids := _padded_voids(heights.void_mask)
		var lands := _land_corners(voids)
		var cells := TerrainGrid.SIDE - 1
		for z in cells:
			for x in cells:
				_add_land(soup, heights.heights_m, lands[z * TerrainGrid.SIDE + x], x, z)
		for z in cells:
			for x in cells:
				_add_walls(soup, heights.heights_m, voids, lands[z * TerrainGrid.SIDE + x], x, z)
	var data := MapTerrainData.new()
	data.vertices = soup.vertices
	data.normals = soup.normals
	data.indices = soup.indices
	return data


## The two land triangles of a full cell, one when exactly one corner is void, none otherwise (`land`: corner bits).
static func _add_land(soup: _Soup, heights_m: PackedFloat32Array, land: int, x: int, z: int) -> void:
	if land & 1:
		if (land & 6) == 6:
			_add_triangle(soup, heights_m, x, z, 0, 1, 2)
	elif (land & 14) == 14:
		_add_triangle(soup, heights_m, x, z, 1, 2, 3)
	if land & 4:
		if (land & 9) == 9:
			_add_triangle(soup, heights_m, x, z, 2, 3, 0)
	elif (land & 11) == 11:
		_add_triangle(soup, heights_m, x, z, 0, 1, 3)


## The side walls of a cell on the rim, then the wall across it when exactly one corner is void.
static func _add_walls(soup: _Soup, heights_m: PackedFloat32Array, voids: PackedByteArray, land: int, x: int, z: int) -> void:
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
			_add_wall(soup, heights_m, x, z, a, b)
	if count == 3:
		var gone := 0
		while land & (1 << gone):
			gone += 1
		_add_wall(soup, heights_m, x, z, (gone + 3) % 4, (gone + 1) % 4)


## A strip that drops HoleWallRules.DEPTH_M under the rim from corner a to corner b, as two triangles.
static func _add_wall(soup: _Soup, heights_m: PackedFloat32Array, x: int, z: int, a: int, b: int) -> void:
	var top_a := _corner_point(heights_m, x, z, a)
	var top_b := _corner_point(heights_m, x, z, b)
	var down := Vector3(0.0, -HoleWallRules.DEPTH_M, 0.0)
	soup.add(top_a, top_b + down, top_b, true)
	soup.add(top_b + down, top_a, top_a + down, true)


static func _add_triangle(soup: _Soup, heights_m: PackedFloat32Array, x: int, z: int, a: int, b: int, c: int) -> void:
	soup.add(_corner_point(heights_m, x, z, a), _corner_point(heights_m, x, z, b), _corner_point(heights_m, x, z, c), false)


static func _corner_point(heights_m: PackedFloat32Array, x: int, z: int, corner: int) -> Vector3:
	var vx := x + CORNERS[corner].x
	var vz := z + CORNERS[corner].y
	return Vector3(vx * TerrainGrid.CELL_M, heights_m[vz * TerrainGrid.SIDE + vx], vz * TerrainGrid.CELL_M)


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


## The triangles as they are made: three vertices each, their flat normal, and the indices.
class _Soup:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	## Godot's front face is the opposite of the right-hand normal: land keeps its corner order, so it faces up; a wall
	## is flipped, so its face is the one seen from the void.
	func add(a: Vector3, b: Vector3, c: Vector3, wall: bool) -> void:
		var start := vertices.size()
		vertices.append(a)
		vertices.append(b)
		vertices.append(c)
		var right := (b - a).cross(c - a)
		var normal := right if wall else -right
		normal = Vector3.UP if normal == Vector3.ZERO else normal.normalized()
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		if wall:
			indices.append_array([start, start + 2, start + 1])
		else:
			indices.append_array([start, start + 1, start + 2])
