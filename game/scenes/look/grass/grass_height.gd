class_name GrassHeight
extends RefCounted

## The land height the grass layer reads, derived from the terrain when the grass loads instead of read from a
## baked height.exr. RG float, 1024x1024 over the whole map (2.5 m per texel on a 2560 m map): R = height, G = 1 where land
## lies under the texel centre (`Terrain.height_at` is not NAN), 0 over holes and the map rim. Hole texels take the
## height of the nearest land texel so a bilinear read near a hole edge does not dip to 0. The grass is off today, so this
## costs nothing at start-up; it runs once, when a grass field first loads.

const SIZE := 1024


## `shape`: a loaded Terrain (height_at is NAN over a hole).
static func from_shape(shape: Terrain) -> Image:
	var texel := shape.bounds().size.x / float(SIZE)
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var land := PackedByteArray()
	land.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var found: float = shape.height_at((x + 0.5) * texel, (y + 0.5) * texel)
			var at := y * SIZE + x
			if is_nan(found):
				heights[at] = NAN
				land[at] = 0
			else:
				heights[at] = found
				land[at] = 1
	_fill_holes(heights, land)
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 8)
	for i in SIZE * SIZE:
		data.encode_float(i * 8, heights[i])
		data.encode_float(i * 8 + 4, float(land[i]))
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGF, data)


## Breadth-first fill, ring by ring: each hole texel copies a land neighbour (first of +x, -x, +z, -z) that an EARLIER ring
## filled. Only the frontier is visited each ring, so the cost is one pass over the holes, not one pass per ring.
static func _fill_holes(heights: PackedFloat32Array, land: PackedByteArray) -> void:
	var filled := land.duplicate()
	var queued := PackedByteArray()
	queued.resize(SIZE * SIZE)
	var frontier := PackedInt32Array()
	for at in SIZE * SIZE:
		if filled[at] == 0 and _touches_filled(filled, at):
			queued[at] = 1
			frontier.append(at)
	var ring := 0
	while not frontier.is_empty() and ring < SIZE:
		ring += 1
		for at in frontier:
			heights[at] = heights[_first_filled_neighbour(filled, at)]
		for at in frontier:
			filled[at] = 1
		var next := PackedInt32Array()
		for at in frontier:
			var x := at % SIZE
			var y := at / SIZE
			for other in [
				at + 1 if x + 1 < SIZE else -1,
				at - 1 if x > 0 else -1,
				at + SIZE if y + 1 < SIZE else -1,
				at - SIZE if y > 0 else -1
			]:
				if other >= 0 and filled[other] == 0 and queued[other] == 0:
					queued[other] = 1
					next.append(other)
		frontier = next
	for i in SIZE * SIZE:
		if filled[i] == 0:
			heights[i] = 0.0


static func _first_filled_neighbour(filled: PackedByteArray, at: int) -> int:
	var x := at % SIZE
	var y := at / SIZE
	if x + 1 < SIZE and filled[at + 1] == 1:
		return at + 1
	if x > 0 and filled[at - 1] == 1:
		return at - 1
	if y + 1 < SIZE and filled[at + SIZE] == 1:
		return at + SIZE
	if y > 0 and filled[at - SIZE] == 1:
		return at - SIZE
	return -1


static func _touches_filled(filled: PackedByteArray, at: int) -> bool:
	return _first_filled_neighbour(filled, at) >= 0
