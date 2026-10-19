class_name UnitAir
extends Node

## RFC-036 036j follow-up: the vertical half of a UnitBody step. Seats the body on the ground when it spawns, holds the
## height of a creature that must fly, finds the ground under it and takes a walk by air (F116, RFC-030e). The body
## calls it from its physics step; it holds no mode and no order.

@export var body: UnitBody
## Ray casts left to seat the body on the ground (UnitBody sets it when it spawns on the server).
var seat_left := 0


## Puts the body on the ground under it; true while it is still seating (the step does nothing else).
func seat() -> bool:
	if seat_left <= 0:
		return false
	var hit := _ray(body.global_position)
	seat_left -= 1
	if hit.is_empty():
		return true
	body.global_position.y = float(hit.position.y)
	body.velocity = Vector3.ZERO
	seat_left = 0
	return true


## The ground height under `at` (NAN off the map).
func ground_height(at: Vector3) -> float:
	var hit := _ray(at)
	return float(hit.position.y) if not hit.is_empty() else NAN


## A creature that must fly keeps `flying_height` over the ground.
func hold_height(delta: float) -> void:
	var ground_y := ground_height(body.global_position)
	if not is_finite(ground_y):
		body.velocity.y = 0.0
		return
	var dy := ground_y + body.flying_height - body.global_position.y
	if absf(dy) < 0.001:
		body.velocity.y = 0.0
		return
	var step := body.flying_hover_speed * delta
	if absf(dy) <= step:
		body.velocity.y = dy / maxf(delta, 0.000001)
	else:
		body.velocity.y = signf(dy) * body.flying_hover_speed


## F116: a hybrid in the air keeps its flying pace; the avoidance turns its heading but does not add to
## it (sacengine caps the air speed at speedInAir, state.d:14742-14751).
func cap_pace() -> void:
	var pace := body.move_speed * body.speed_factor
	var flat := Vector2(body.velocity.x, body.velocity.z)
	if pace > 0.0 and flat.length() > pace:
		flat = flat.normalized() * pace
		body.velocity.x = flat.x
		body.velocity.z = flat.y


## F116: the Flight child takes the walk to `point` by air (sacengine moveTowards, state.d:12335-12339). A flier goes
## straight: its waypoints are dropped.
func flies_to(point: Vector3) -> bool:
	if not body.simulates():
		return false
	var type := body.type
	var flight := body.flight
	var follower := body.path_follower
	## A creature that must fly has no Flight child (it is never on the ground): it always goes straight, no path on the navmesh or the grid.
	if type != null and type.is_flying():
		if is_instance_valid(follower):
			follower.cancel()
		return true
	if flight == null:
		return false
	var flat := Vector2(point.x - body.global_position.x, point.z - body.global_position.z).length()
	if not flight.goes_by_air(flat):
		return false
	if is_instance_valid(follower):
		follower.cancel()
	return true


## A hybrid that stands on the ground takes the walk by air when the whole leg is worth flying; the goal becomes the
## end of its waypoints.
func reroute() -> void:
	var flight := body.flight
	if flight == null or flight.state != Flight.State.GROUND or not flight.is_capable():
		return
	var final_goal := body.walk_goal()
	var follower := body.path_follower
	if is_instance_valid(follower) and follower.is_active():
		final_goal = follower.goal
	if flies_to(final_goal):
		body.set_walk_goal(final_goal)


func _ray(at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = body.ground_mask
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(query)
