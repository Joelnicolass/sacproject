class_name BrushRules
extends RefCounted

## What one dab of a ground brush does to the ground's numbers: how strongly each vertex of a rect is touched (weights),
## and raise, smooth, flatten and void paint over that rect. Every edit works IN PLACE on the arrays it gets (heights in
## metres and the void mask, TerrainGrid.COUNT values row by row, as in TerrainHeights) and writes only the vertices of
## `rect`; the caller knows the rect, so nothing is returned. `weighted` must come from `weights()` for the same rect.
## Heights stay in 0..MAX_HEIGHT_M. Not: the stroke (BrushStroke), undo, the editor, the mesh. Pure and static.

## The highest ground a 16-bit height image holds: 65535 steps of 0.1 m.
const MAX_HEIGHT_M := 6553.5
## Void paint has no soft edge: a vertex whose weight is above this is inside the brush.
const SHAPE_WEIGHT := 0.5
## Each arm of the cross is this fraction of the brush's reach wide, on each side of its centre line.
const CROSS_ARM := 1.0 / 3.0


## How strongly the brush, centred on the ground point `center` (x, z in metres), touches each vertex of `rect`, row by
## row: 1 inside the hard core (`size_m * (1 - falloff)` from the centre), easing to 0 at `size_m`, 0 beyond.
static func weights(brush: TerrainBrush, center: Vector2, rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.size.x * rect.size.y)
	var core_m := brush.size_m * (1.0 - brush.falloff)
	var i := 0
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var distance_m := _distance(brush.shape, TerrainGrid.point_of(Vector2i(x, z)) - center)
			out[i] = _weight(distance_m, core_m, brush.size_m)
			i += 1
	return out


## Moves every vertex of `rect` up by `delta_m` times its weight (down when `delta_m` is negative).
static func raise(heights: PackedFloat32Array, rect: Rect2i, weighted: PackedFloat32Array, delta_m: float) -> void:
	var vertices := ids(rect)
	for i in vertices.size():
		heights[vertices[i]] = _clamped(heights[vertices[i]] + weighted[i] * delta_m)


## One smoothing pass: every vertex of `rect` moves towards the mean of itself and its 8 neighbours, by its weight times
## `strength` (0..1). All means are read before any vertex moves, so the result does not depend on the order.
static func smooth(heights: PackedFloat32Array, rect: Rect2i, weighted: PackedFloat32Array, strength: float) -> void:
	var vertices := ids(rect)
	var smoothed := PackedFloat32Array()
	smoothed.resize(vertices.size())
	for i in vertices.size():
		smoothed[i] = lerpf(heights[vertices[i]], _mean_around(heights, vertices[i]), weighted[i] * strength)
	for i in vertices.size():
		heights[vertices[i]] = _clamped(smoothed[i])


## Moves every vertex of `rect` towards `target_m` by its weight: weight 1 ends exactly at `target_m`.
static func flatten(heights: PackedFloat32Array, rect: Rect2i, weighted: PackedFloat32Array, target_m: float) -> void:
	var vertices := ids(rect)
	var target := _clamped(target_m)
	for i in vertices.size():
		heights[vertices[i]] = target if weighted[i] >= 1.0 else _clamped(lerpf(heights[vertices[i]], target, weighted[i]))


## Makes the vertices of `rect` inside the brush (weight above SHAPE_WEIGHT) void (`on`) or land again (not `on`). The
## heights are not touched, so filling brings back the ground that was there.
static func paint_void(mask: PackedByteArray, rect: Rect2i, weighted: PackedFloat32Array, on: bool) -> void:
	var vertices := ids(rect)
	for i in vertices.size():
		if weighted[i] > SHAPE_WEIGHT:
			mask[vertices[i]] = 1 if on else 0


## The ids of the vertices of `rect`, row by row: the order of `weights()` and of a BrushStroke.Patch.
static func ids(rect: Rect2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(TerrainGrid.id_of(Vector2i(x, z)))
	return out


## How far `offset` (metres from the centre) is from the centre in the brush's shape: the shape's edge is where this
## equals the brush's reach.
static func _distance(shape: TerrainBrush.Shape, offset: Vector2) -> float:
	var along := offset.abs()
	match shape:
		TerrainBrush.Shape.SQUARE:
			return maxf(along.x, along.y)
		TerrainBrush.Shape.CROSS:
			return maxf(maxf(along.x, along.y), minf(along.x, along.y) / CROSS_ARM)
	return offset.length()


static func _weight(distance_m: float, core_m: float, size_m: float) -> float:
	if distance_m >= size_m:
		return 0.0
	if distance_m <= core_m:
		return 1.0
	return smoothstep(0.0, 1.0, (size_m - distance_m) / (size_m - core_m))


## The mean height of vertex `id` and its neighbours that lie on the lattice.
static func _mean_around(heights: PackedFloat32Array, id: int) -> float:
	var vertex := TerrainGrid.vertex_of(id)
	var low := (vertex - Vector2i.ONE).max(Vector2i.ZERO)
	var high := (vertex + Vector2i.ONE).min(Vector2i(TerrainGrid.SIDE - 1, TerrainGrid.SIDE - 1))
	var total := 0.0
	for z in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			total += heights[TerrainGrid.id_of(Vector2i(x, z))]
	return total / float((high.x - low.x + 1) * (high.y - low.y + 1))


static func _clamped(height_m: float) -> float:
	return clampf(height_m, 0.0, MAX_HEIGHT_M)
