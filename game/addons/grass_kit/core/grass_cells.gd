@tool
class_name GrassCells
extends RefCounted

## The square cells of a grass field, anchored at (0, 0): which ones a ring around a centre holds,
## and where each one is. Pure math, no nodes.


## The cells whose square comes within `radius` of `center` (x, z), each with the distance from
## `center` to its nearest point.
static func around(center: Vector2, radius: float, size: float) -> Dictionary[Vector2i, float]:
	var out: Dictionary[Vector2i, float] = {}
	var low := Vector2i(floori((center.x - radius) / size), floori((center.y - radius) / size))
	var high := Vector2i(floori((center.x + radius) / size), floori((center.y + radius) / size))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var cell := Vector2i(x, z)
			var rect := rect_of(cell, size)
			var nearest := center.clamp(rect.position, rect.end).distance_to(center)
			if nearest <= radius:
				out[cell] = nearest
	return out


## The square of `cell` on the ground plane.
static func rect_of(cell: Vector2i, size: float) -> Rect2:
	return Rect2(Vector2(cell) * size, Vector2(size, size))
