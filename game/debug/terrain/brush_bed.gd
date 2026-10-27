extends RefCounted

## The ground and brushes brush_cases works on: a whole lattice of flat land at BASE_M (row by row, as TerrainHeights keeps
## it), seeded noise on a patch, and the brush shapes worked out apart from BrushRules to check it against. Not: the
## checks themselves (brush_cases.gd). Static; preloaded by the cases.

const BASE_M := 100.0
const NOISE_M := 5.0


## Inside the shape, worked out apart from BrushRules: the circle, the square, the plus sign with arms a third wide.
static func inside(shape: TerrainBrush.Shape, offset: Vector2, size_m: float) -> bool:
	var along := offset.abs()
	match shape:
		TerrainBrush.Shape.SQUARE:
			return maxf(along.x, along.y) < size_m
		TerrainBrush.Shape.CROSS:
			return maxf(along.x, along.y) < size_m and minf(along.x, along.y) < size_m / 3.0
	return offset.length() < size_m


## A brush raising 0.1 m per pixel.
static func brush(size_m: float, falloff: float, shape: TerrainBrush.Shape) -> TerrainBrush:
	var made := TerrainBrush.new()
	made.size_m = size_m
	made.falloff = falloff
	made.shape = shape
	made.strength_m = 0.1
	return made


## Flat ground at BASE_M over the whole lattice (row by row, as TerrainHeights keeps it).
static func flat() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(TerrainGrid.COUNT)
	heights.fill(BASE_M)
	return heights


## A void mask with no void.
static func land() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(TerrainGrid.COUNT)
	mask.fill(0)
	return mask


## Adds seeded noise of up to NOISE_M to the vertices within `reach` vertices of `around`.
static func noisy(heights: PackedFloat32Array, around: Vector2i, reach: int) -> PackedFloat32Array:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for id in BrushRules.ids(Rect2i(around - Vector2i.ONE * reach, Vector2i.ONE * (2 * reach + 1))):
		heights[id] = BASE_M + random.randf_range(-NOISE_M, NOISE_M)
	return heights


static func variance(heights: PackedFloat32Array, rect: Rect2i) -> float:
	var total := 0.0
	var squares := 0.0
	var vertices := BrushRules.ids(rect)
	for id in vertices:
		total += heights[id]
		squares += heights[id] * heights[id]
	var mean := total / vertices.size()
	return squares / vertices.size() - mean * mean


static func at(heights: PackedFloat32Array, x: int, z: int) -> float:
	return heights[TerrainGrid.id_of(Vector2i(x, z))]


## Equal for two grounds only when heights and voids are equal bit for bit (as TerrainHeights.checksum).
static func checksum(heights: PackedFloat32Array, mask: PackedByteArray) -> int:
	return hash(heights.to_byte_array() + mask)
