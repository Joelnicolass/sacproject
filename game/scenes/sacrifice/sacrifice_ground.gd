class_name SacrificeGround
extends RefCounted

## The one place the sacrifice asks the map's ground: the height under a point and whether there is land there. A scene with no
## ground loaded (a bare test world) answers «land, at the point's own height». What it does not do: hold the ground (GroundSurface
## does) or move anything.


## True when the point stands over land (or there is no ground to ask).
static func on_ground(from: Node, point: Vector3) -> bool:
	var shape := GroundSurface.of(from)
	return shape == null or shape.is_on_ground(point.x, point.z)


## Land height under the point; the point's own height without ground data or over a hole.
static func height_at(from: Node, point: Vector3) -> float:
	var shape := GroundSurface.of(from)
	if shape == null:
		return point.y
	var y := shape.height_at(point.x, point.z)
	return point.y if is_nan(y) else y
