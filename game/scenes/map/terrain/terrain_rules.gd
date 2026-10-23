class_name TerrainRules
extends RefCounted

## The ground's arithmetic with no tree: which land triangle lies under a point, how high the land is there, and how
## the raw triangles of a MapTerrainData become the per-cell index. Pure and static, so a WorkerThreadPool task can
## call it on copies of an index. What it does NOT do: hold the data (TerrainShape) or build the mesh (Terrain).
## Ref: sacmap.d getTriangles, isInside, getGroundHeight.

const CELL := 10.0
const GRID := 256
## Edge tolerance of the inside test; a point on an edge counts as inside.
const EDGE_TOLERANCE := 0.0001
## A triangle with less area than this seen from above is a cliff wall, not land.
const WALL_AREA := 0.01


## The land of a map ready to be asked: `ground` holds three vertices per land triangle; `cells` two triangle ids per
## 10 m cell (-1 when the cell has fewer); `lowest` is the lowest land vertex (0 without land).
class Index:
	var ground := PackedVector3Array()
	var cells := PackedInt32Array()
	var lowest := 0.0


## Splits the land from the cliff walls of `data` and files each land triangle under the 10 m cell of its lowest corner.
static func index(data: MapTerrainData) -> Index:
	var result := Index.new()
	result.cells.resize(GRID * GRID * 2)
	result.cells.fill(-1)
	result.lowest = INF
	if data == null:
		result.lowest = 0.0
		return result
	var vertices := data.vertices
	var indices := data.indices
	var triangle := 0
	while triangle < indices.size():
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		triangle += 3
		if is_wall(a, b, c):
			continue
		var cell_x := clampi(int(round(minf(minf(a.x, b.x), c.x) / CELL)), 0, GRID - 1)
		var cell_z := clampi(int(round(minf(minf(a.z, b.z), c.z) / CELL)), 0, GRID - 1)
		var slot := (cell_z * GRID + cell_x) * 2
		if result.cells[slot] >= 0:
			slot += 1
		if result.cells[slot] >= 0:
			continue
		result.cells[slot] = result.ground.size() / 3
		result.ground.append_array([a, b, c])
		result.lowest = minf(result.lowest, minf(minf(a.y, b.y), c.y))
	if result.ground.is_empty():
		result.lowest = 0.0
	return result


## True for a triangle that has no area seen from above (a cliff wall).
static func is_wall(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return absf(flat_cross(a, b, Vector2(c.x, c.z))) < WALL_AREA


## Land height under (x, z) in world units, NAN over a hole or off the map.
static func height_in(x: float, z: float, ground: PackedVector3Array, cells: PackedInt32Array) -> float:
	var id := triangle_in(x, z, ground, cells)
	if id < 0:
		return NAN
	var plane := Plane(ground[id * 3], ground[id * 3 + 1], ground[id * 3 + 2])
	return (plane.d - plane.normal.x * x - plane.normal.z * z) / plane.normal.y


## The land triangle under (x, z) (an id into `ground`), -1 over a hole or off the map.
static func triangle_in(x: float, z: float, ground: PackedVector3Array, cells: PackedInt32Array) -> int:
	if ground.is_empty():
		return -1
	var cell_x := int(floor(x / CELL))
	var cell_z := int(floor(z / CELL))
	if cell_x < 0 or cell_z < 0 or cell_x >= GRID or cell_z >= GRID:
		return -1
	var at := Vector2(x, z)
	for k in 2:
		var id := cells[(cell_z * GRID + cell_x) * 2 + k]
		if id < 0:
			continue
		if _inside(ground, id, at):
			return id
	return -1


## Edges count as inside, with either winding.
static func _inside(ground: PackedVector3Array, id: int, at: Vector2) -> bool:
	var a := ground[id * 3]
	var b := ground[id * 3 + 1]
	var c := ground[id * 3 + 2]
	var s0 := flat_cross(a, b, at)
	var s1 := flat_cross(b, c, at)
	var s2 := flat_cross(c, a, at)
	return (s0 >= -EDGE_TOLERANCE and s1 >= -EDGE_TOLERANCE and s2 >= -EDGE_TOLERANCE) \
			or (s0 <= EDGE_TOLERANCE and s1 <= EDGE_TOLERANCE and s2 <= EDGE_TOLERANCE)


## Cross product of (b - a) and (at - a) on the ground plane (x, z).
static func flat_cross(a: Vector3, b: Vector3, at: Vector2) -> float:
	return (b.x - a.x) * (at.y - a.z) - (b.z - a.z) * (at.x - a.x)
