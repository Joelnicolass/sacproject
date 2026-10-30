class_name EdgeClamp
extends RefCounted

## A walking body does not step off the land. Paths come from the navmesh and the terrain and the
## buildings collide; this covers what is left: a body the avoidance (or a crowd) pushes toward a
## hole or a cliff. Call it on the velocity right before move_and_slide. The terrain answers «is the
## next step on the ground?» (one lookup in the heightmap, the common case ends there); only when it
## is not, the navmesh gives the closest land point and the step is cut to it (the navmesh edge is
## inset by the agent radius, so the capsule stays over the ground). Without a NavService the
## horizontal step is dropped. A body thrown on purpose (Tumbling) is not clamped: it falls.


## `velocity` whose horizontal step from the body's position this tick stays on the land. Y is kept.
static func clamp_velocity(body: Node3D, velocity: Vector3, delta: float) -> Vector3:
	var shape := Terrain.of(body)
	if shape == null or delta <= 0.0:
		return velocity
	var at := body.global_position
	var step := Vector2(velocity.x, velocity.z) * delta
	if step.length_squared() < 0.0000001 or not shape.is_on_ground(at.x, at.z):
		return velocity
	if shape.is_on_ground(at.x + step.x, at.z + step.y):
		return velocity
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling != null and tumbling.is_on():
		return velocity
	var land := _land_near(body, Vector3(at.x + step.x, at.y, at.z + step.y))
	if is_nan(land.x):
		return Vector3(0.0, velocity.y, 0.0)
	var cut := Vector2(land.x - at.x, land.z - at.z)
	if cut.length() > step.length():
		cut = cut.normalized() * step.length()
	return Vector3(cut.x / delta, velocity.y, cut.y / delta)


## The closest free land to `point`, (NAN, NAN, NAN) when there is none or no ready NavService.
static func _land_near(body: Node3D, point: Vector3) -> Vector3:
	var nav := body.get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if nav == null or not nav.is_ready():
		return Vector3(NAN, NAN, NAN)
	return nav.nearest_free(point)
