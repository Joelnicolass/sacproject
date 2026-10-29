@tool
class_name PropObstruction
extends RefCounted

## One blocker of a navmesh bake, read from a prop's collision shape: its outline on the ground
## plane and, in 3D, the heights it spans. PropObstructions makes them and adds them to a bake.

## The outline on the ground plane, in global coordinates: (x, z) in 3D, (x, y) in 2D.
var outline := PackedVector2Array()
## Lowest and highest point (3D).
var bottom := 0.0
var top := 0.0


## The outline's bounds on the ground plane.
func rect() -> Rect2:
	if outline.is_empty():
		return Rect2()
	var out := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		out = out.expand(point)
	return out
