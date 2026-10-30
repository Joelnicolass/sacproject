class_name RtsSpace
extends RefCounted

## The one space the kit thinks in, for 2D and 3D games alike: the ground is the XZ plane and Y is up
## (3D world coordinates as they are). A 2D game's world point (x, y) is the kit point (x, 0, y): seen
## from above, the 3D ground and a 2D top-down map are the same picture (x to the right, z / y down
## the screen), so one formation, one distance and one yaw serve both. Only the edges convert: a body's
## position, a camera, a pointer.
##
## Yaw: forward is (sin yaw, 0, cos yaw) and right is (-cos yaw, 0, sin yaw), so yaw 0 faces +Z (down
## the screen in 2D) and its right hand points to -X. Formation slots are (right, forward) in world
## units (meters in 3D, pixels in 2D).
## Not: what a unit is (RtsUnit), what a camera does (RtsCamera3D / RtsCamera2D).


## Forward on the ground for `yaw`.
static func ahead(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Right on the ground for `yaw` (ahead × up).
static func right(yaw: float) -> Vector3:
	return ahead(yaw).cross(Vector3.UP)


## The yaw whose forward is `direction` (its Y is ignored).
static func yaw_of_direction(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


## A 2D world point as a kit point.
static func from_2d(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


## A kit point as a 2D world point.
static func to_2d(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## Where a body stands, as a kit point: a Node3D's global position, a Node2D's as (x, 0, y). Anything
## else is the origin.
static func position_of(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	if node is Node2D:
		return from_2d((node as Node2D).global_position)
	return Vector3.ZERO


## Moves a body to a kit point (a Node2D drops the Y).
static func place(node: Node, point: Vector3) -> void:
	if node is Node3D:
		(node as Node3D).global_position = point
	elif node is Node2D:
		(node as Node2D).global_position = to_2d(point)


## The way a body faces, as a kit yaw. A Node3D faces +Z of its basis (Godot's MODEL_FRONT); a Node2D
## faces +X rotated by its global rotation.
static func yaw_of_node(node: Node) -> float:
	if node is Node3D:
		var front := (node as Node3D).global_basis.z
		return atan2(front.x, front.z)
	if node is Node2D:
		var r := (node as Node2D).global_rotation
		return atan2(cos(r), sin(r))
	return 0.0


## True for a 2D body (Node2D); false for 3D and anything else.
static func is_2d(node: Node) -> bool:
	return node is Node2D


## Where a kit point is drawn on `viewport`'s screen, in viewport pixels, or null when a 3D camera has
## it behind. `node_2d` decides how: a 2D point goes through the canvas transform, a 3D one through
## the viewport's Camera3D (no camera: null).
static func screen_of(viewport: Viewport, point: Vector3, node_2d: bool) -> Variant:
	if viewport == null:
		return null
	if node_2d:
		return viewport.get_canvas_transform() * to_2d(point)
	var camera := viewport.get_camera_3d()
	if camera == null or camera.is_position_behind(point):
		return null
	return camera.unproject_position(point)


## The 2D world point under a screen pixel of `viewport` (the canvas transform undone).
static func world_2d_at(viewport: Viewport, screen: Vector2) -> Vector2:
	return viewport.get_canvas_transform().affine_inverse() * screen
