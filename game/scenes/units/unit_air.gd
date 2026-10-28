class_name UnitAir
extends Node

## The vertical half of a creature's step: seats the body on the ground when it spawns, gives it gravity or the lift of a flier
## (holds the height of one that must fly, takes off and lands a hybrid), finds the ground under it and decides when a walk goes by air.
## Not: the horizontal walk (Locomotion) nor when to step (the body calls it from its physics step); it holds no mode and no order.

@export var body: UnitBody
## Height over the ground (m) a creature that must fly keeps.
@export var flying_height := 4.5
## Vertical speed (m/s) at which it climbs or sinks to that height.
@export var flying_hover_speed := 3.0
## Ray casts the body gets to find the ground and sit on it when it spawns on the server.
@export var seat_attempts := 12
## Ray casts left to seat the body on the ground (UnitBody sets it when it spawns on the server).
var seat_left := 0


## Puts the body on the ground under it; true while it is still seating (the step does nothing else).
func seat() -> bool:
	if seat_left <= 0:
		return false
	var ground_y := ground_height(body.global_position)
	seat_left -= 1
	if is_nan(ground_y):
		return true
	body.global_position.y = ground_y
	body.velocity = Vector3.ZERO
	seat_left = 0
	return true


## Gravity, or the lift of a flier, for this step (Locomotion.begin). `walking`: the body is in MOVE. True when the body flew as
## the step began.
func step_vertical(delta: float, walking: bool) -> bool:
	var must_fly := body.type != null and body.type.is_flying()
	var airborne := body.is_flying()
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var flight := body.flight
	if must_fly and not (flight != null and flight.is_dropped()):
		hold_height(delta)
	elif flight != null and (must_fly or flight.is_capable()):
		var above := (
			body.global_position.y - ground_height(body.global_position) if airborne else 0.0
		)
		var lift := flight.advance(delta, walking, above, body.is_on_floor())
		if airborne:
			body.velocity.y = lift
		elif body.is_on_floor():
			body.velocity.y = 0.0
		else:
			body.velocity.y -= gravity * delta
	elif body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= gravity * delta
	return airborne


## The ground height under `at` (NAN off the map).
func ground_height(at: Vector3) -> float:
	return GroundRay.surface_y(body, at, body.ground_mask, [body.get_rid()], NAN)


## A creature that must fly keeps `flying_height` over the ground.
func hold_height(delta: float) -> void:
	var ground_y := ground_height(body.global_position)
	if not is_finite(ground_y):
		body.velocity.y = 0.0
		return
	var dy := ground_y + flying_height - body.global_position.y
	if absf(dy) < 0.001:
		body.velocity.y = 0.0
		return
	var step := flying_hover_speed * delta
	if absf(dy) <= step:
		body.velocity.y = dy / maxf(delta, 0.000001)
	else:
		body.velocity.y = signf(dy) * flying_hover_speed


## A flight that holds the body still (landing, taking off) leaves it no flat speed.
func hold_still() -> void:
	if body.flight != null and body.flight.holds_still():
		body.velocity.x = 0.0
		body.velocity.z = 0.0


## A hybrid in the air keeps its flying pace: the avoidance turns its heading but does not add to it.
func cap_pace() -> void:
	if body.flight == null or not body.flight.is_airborne():
		return
	var pace := body.move_speed * body.speed_factor
	var flat := Vector2(body.velocity.x, body.velocity.z)
	if pace > 0.0 and flat.length() > pace:
		flat = flat.normalized() * pace
		body.velocity.x = flat.x
		body.velocity.z = flat.y


## The Flight child takes the walk to `point` by air. A flier goes
## straight: its waypoints are dropped.
func flies_to(point: Vector3) -> bool:
	if not body.simulates():
		return false
	var type := body.type
	var flight := body.flight
	var follower := body.path_follower
	# A creature that must fly has no Flight child (it is never on the ground): it always goes straight, no path on the navmesh or the grid.
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
	var final_goal := body.locomotion.goal
	var follower := body.path_follower
	if is_instance_valid(follower) and follower.is_active():
		final_goal = follower.goal
	if flies_to(final_goal):
		body.locomotion.goal = final_goal
