class_name TerrainGrid
extends RefCounted

## Where the vertices of a map's ground lie: a square lattice of SIDE x SIDE vertices, CELL_M metres apart, from the origin
## (x, z >= 0), and the arithmetic between a point in metres, a vertex (column, row) and its id (row * SIDE + column; a 10 m
## cell has the id of its low corner). The one place of these numbers: the ground shader keeps one mirror
## (look/ground/terrain_deform.gdshaderinc) that must change with it. Not: how high a vertex is, whether
## it is land or a hole (GroundField, TerrainRules). Pure and static.

## Vertices per side of the lattice (and 10 m cells per side of a map's tile index).
const SIDE := 256
## Metres between two neighbouring vertices.
const CELL_M := 10.0
## The side of a map's footprint in metres.
const SIZE_M := SIDE * CELL_M
## Vertices (or cells) in the whole lattice.
const COUNT := SIDE * SIDE


## The id of the vertex nearest to the ground point (x, z) in metres, cut to the lattice.
static func vertex_id(x: float, z: float) -> int:
	return clampi(roundi(z / CELL_M), 0, SIDE - 1) * SIDE + clampi(roundi(x / CELL_M), 0, SIDE - 1)


## The id of the vertex (column, row). It does not check that the vertex lies on the lattice.
static func id_of(vertex: Vector2i) -> int:
	return vertex.y * SIDE + vertex.x


## The vertex (column, row) of the id.
static func vertex_of(id: int) -> Vector2i:
	return Vector2i(id % SIDE, id / SIDE)


## The ground point (x, z) in metres of the vertex (column, row).
static func point_of(vertex: Vector2i) -> Vector2:
	return Vector2(vertex) * CELL_M


## The vertex (column, row) nearest to the ground point (x, z) in metres. Not cut to the lattice.
static func vertex_near(point: Vector2) -> Vector2i:
	return Vector2i(
		floori((point.x + CELL_M * 0.5) / CELL_M), floori((point.y + CELL_M * 0.5) / CELL_M)
	)


## The vertices that lie within `radius_m` of the ground point `center` (x, z), cut to the lattice.
static func vertex_rect(center: Vector2, radius_m: float) -> Rect2i:
	var low := Vector2i(
		floori((center.x - radius_m) / CELL_M), floori((center.y - radius_m) / CELL_M)
	)
	var high := Vector2i(
		ceili((center.x + radius_m) / CELL_M), ceili((center.y + radius_m) / CELL_M)
	)
	low = low.clamp(Vector2i.ZERO, Vector2i(SIDE - 1, SIDE - 1))
	high = high.clamp(Vector2i.ZERO, Vector2i(SIDE - 1, SIDE - 1))
	return Rect2i(low, high - low + Vector2i.ONE)


## The ground area (x, z in metres) that a rect of vertices spans.
static func area_of(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) * CELL_M, Vector2(rect.size) * CELL_M)


## The smallest rect of vertices holding both; an empty one adds nothing.
static func union(a: Rect2i, b: Rect2i) -> Rect2i:
	return b if not a.has_area() else (a if not b.has_area() else a.merge(b))
