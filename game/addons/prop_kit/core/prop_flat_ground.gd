@tool
class_name PropFlatGround
extends PropGround

## Flat ground at `height` over `area`, or only inside `outline` when it has three points or more
## (a polygon on the ground plane, in global coordinates). The usual ground of a 2D scatter.

## The area to scatter over. Empty = the outline's bounds.
@export var area := Rect2(-50.0, -50.0, 100.0, 100.0)
## Only inside this polygon, when it has three points or more.
@export var outline := PackedVector2Array()
## Height of the ground (3D).
@export var height := 0.0


func bounds() -> Rect2:
	if area.has_area() or outline.size() < 3:
		return area
	var out := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		out = out.expand(point)
	return out


func height_at(_at: Vector2) -> float:
	return height


func weight_at(at: Vector2) -> float:
	if outline.size() >= 3 and not Geometry2D.is_point_in_polygon(at, outline):
		return 0.0
	return 1.0
