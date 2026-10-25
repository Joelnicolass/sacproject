class_name SacrificeGround
extends RefCounted

## The one place the sacrifice asks the land: whether a point has ground under it and how high the ground is there. Without a loaded
## map (a bare test world) there is no ground data: every point counts as ground and keeps its own height.
## What it does not do: hold the surface (GroundSurface does) or decide where anything goes.


## Is there land under `point`? Always true without ground data.
static func is_on(node: Node, point: Vector3) -> bool:
	var surface := GroundSurface.of(node)
	return surface == null or surface.is_on_ground(point.x, point.z)


## Land height under `point`; without ground data (or over a hole) the point's own height.
static func height(node: Node, point: Vector3) -> float:
	var surface := GroundSurface.of(node)
	if surface == null:
		return point.y
	var y := surface.height_at(point.x, point.z)
	return point.y if is_nan(y) else y
