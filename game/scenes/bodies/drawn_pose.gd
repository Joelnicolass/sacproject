class_name DrawnPose
extends RefCounted

## Where a body is on the screen right now, for things that follow it while they are drawn (a flame,
## a rope end, a box of ice). With physics interpolation on, a body is drawn a little behind the
## tick it simulates in; whatever follows it from `_process` must follow that drawn place, or it
## shakes against the body. Without interpolation both places are the same, so nothing changes.
## Presentation only, only from `_process`. Never use it in `_physics_process`: the simulation reads
## the pose of the tick (global_transform).


## The drawn position of `node`.
static func origin(node: Node3D) -> Vector3:
	return node.get_global_transform_interpolated().origin


## The drawn place of a point of the world that moves with `body` (a socket, the center of its box):
## the same point, carried from the body's pose of the tick to its drawn pose.
static func point(body: Node3D, world_point: Vector3) -> Vector3:
	return (
		body.get_global_transform_interpolated()
		* (body.global_transform.affine_inverse() * world_point)
	)


## The box of `body` (BodyNudge.box) moved to where the body is drawn.
static func box(body: Node3D) -> AABB:
	var simulated := BodyNudge.box(body)
	simulated.position += origin(body) - body.global_position
	return simulated


## The middle of the body's box (BodyNudge.center) where the body is drawn.
static func center(body: Node3D) -> Vector3:
	return point(body, BodyNudge.center(body))
