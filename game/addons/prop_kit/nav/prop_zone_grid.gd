@tool
class_name PropZoneGrid
extends RefCounted

## A fixed grid of square zones over an area of the ground plane, anchored at (0, 0): a zone's
## lines stay where they are when the area grows. Zones are numbered row by row from `first`.

## Side of a zone (world units).
var size := 64.0
## The first zone's cell: floor(position / size).
var first := Vector2i.ZERO
## Zones per row (x) and rows (y).
var count := Vector2i.ZERO


## The zones of side `zone_size` that cover `area`.
func _init(area := Rect2(), zone_size := 64.0) -> void:
	size = maxf(zone_size, 0.001)
	if not area.has_area():
		return
	first = Vector2i(floori(area.position.x / size), floori(area.position.y / size))
	var last := Vector2i(ceili(area.end.x / size) - 1, ceili(area.end.y / size) - 1)
	count = (last - first + Vector2i.ONE).max(Vector2i.ZERO)


func zone_count() -> int:
	return count.x * count.y


## Every zone, in order.
func all() -> PackedInt32Array:
	var out := PackedInt32Array()
	for zone in zone_count():
		out.append(zone)
	return out


## The area the zones cover.
func area() -> Rect2:
	return Rect2(Vector2(first) * size, Vector2(count) * size)


@warning_ignore("integer_division")
func cell_of(zone: int) -> Vector2i:
	return first + Vector2i(zone % count.x, zone / count.x)


func zone_rect(zone: int) -> Rect2:
	return Rect2(Vector2(cell_of(zone)) * size, Vector2.ONE * size)


## The zone at `point`, or -1 outside the grid.
func zone_at(point: Vector2) -> int:
	var cell := Vector2i(floori(point.x / size), floori(point.y / size)) - first
	if cell.x < 0 or cell.y < 0 or cell.x >= count.x or cell.y >= count.y:
		return -1
	return cell.y * count.x + cell.x


## The zones whose square overlaps `rect`, in order.
func zones_touching(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	if zone_count() == 0 or not area().intersects(rect, true):
		return out
	var low := Vector2i(floori(rect.position.x / size), floori(rect.position.y / size)) - first
	var high := Vector2i(floori(rect.end.x / size), floori(rect.end.y / size)) - first
	low = low.clamp(Vector2i.ZERO, count - Vector2i.ONE)
	high = high.clamp(Vector2i.ZERO, count - Vector2i.ONE)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			out.append(y * count.x + x)
	return out
