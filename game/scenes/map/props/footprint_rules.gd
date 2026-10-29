class_name FootprintRules
extends RefCounted

## How level the land under a structure's base is: the lattice vertices under a GroundFootprint, how
## far apart their heights are, and the height a flatten should bring them to. Not: flattening
## (BrushRules.flatten does it, the editor calls it), whether a vertex is void (TerrainHeights), the
## tolerance a map must meet (tools/audit/check_map). Pure and static. `heights` is a whole lattice
## of heights in metres, row by row (TerrainHeights.heights_m or a working copy of it).


## The vertices of every lattice cell the ground area (x, z in metres) touches, cut to the lattice:
## a base smaller than a cell still gets that cell's four corners, because those make the triangles
## it stands on.
static func vertices_under(area: Rect2) -> Rect2i:
	var center := area.get_center()
	var across := TerrainGrid.vertex_rect(center, area.size.x * 0.5)
	var along := TerrainGrid.vertex_rect(center, area.size.y * 0.5)
	return Rect2i(
		Vector2i(across.position.x, along.position.y), Vector2i(across.size.x, along.size.y)
	)


## The highest minus the lowest height of the vertices in `rect`. 0 for an empty rect.
static func spread_m(heights: PackedFloat32Array, rect: Rect2i) -> float:
	var values := _heights_in(heights, rect)
	if values.is_empty():
		return 0.0
	values.sort()
	return values[values.size() - 1] - values[0]


## The median height of the vertices in `rect` (the mean of the two middle ones for an even count):
## one tall or deep vertex does not drag the level. 0 for an empty rect.
static func level_target(heights: PackedFloat32Array, rect: Rect2i) -> float:
	var values := _heights_in(heights, rect)
	if values.is_empty():
		return 0.0
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 1:
		return values[middle]
	return (values[middle - 1] + values[middle]) * 0.5


static func _heights_in(heights: PackedFloat32Array, rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for row in range(rect.position.y, rect.end.y):
		for column in range(rect.position.x, rect.end.x):
			var id := TerrainGrid.id_of(Vector2i(column, row))
			if id < heights.size():
				out.append(heights[id])
	return out
