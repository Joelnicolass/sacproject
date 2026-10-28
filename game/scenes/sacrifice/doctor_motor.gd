@tool
class_name DoctorMotor
extends Node

## How a Sac Doctor moves on the ground: it walks to a point, turns toward where it goes, steers around the other
## bodies, slides along what it meets and gives way to a sideways nudge of the StuckGuard. A carrier doctor walks by the
## waypoints of a PathFollower (set only in carrier_doctor.tscn); without one it walks in a line.
## What it does not do: decide where to go (the errand and the ritual do), play a clip (DoctorLook) or keep the pose (DoctorBody).
## The server (or solo) runs it; the clients only get the position and rotation of the body.

## Ground creatures turn at pi rad/s.
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
## The goal counts as reached this close (m).
@export_range(0.0, 2.0, 0.01, "suffix:m") var arrive_distance_m := 0.25
## A goal that moved less than this from the one the PathFollower is walking to is the same goal: a carrier chasing a creature
## that shuffles would otherwise plan a path every tick (m).
@export_range(0.0, 20.0, 0.1, "suffix:m") var repath_goal_m := 3.0
@export_group("Sockets")
@export var body: DoctorBody
@export var avoidance: BodyAvoidance
## The carrier doctors have one: they walk by waypoints around pillars and buildings. The ritual doctors do not: they stand on the
## ring of the altar, inside what the grid blocks.
@export var path_follower: PathFollower

## Where the walk goes. Server only.
var goal := Vector3.ZERO
## Sideways nudge of the StuckGuard: radians the walk heading is rotated for dodge_left seconds.
var dodge_angle := 0.0
var dodge_left := 0.0

var _walking := false


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if body == null:
		out.append("Assign `body` (the DoctorBody it moves).")
	if avoidance == null:
		out.append(
			"Assign `avoidance` (BodyAvoidance): without it the doctors walk through each other."
		)
	return out


func is_walking() -> bool:
	return _walking


## The walk is over (arrived, stopped, working or dead).
func halt() -> void:
	_walking = false


## Walks to `point` with collision: by the waypoints of the PathFollower when there is one, else in a line. `arrived` fires at the
## end of each leg. Calling it again with a new point just moves the goal; the same point (within `repath_goal_m`) while a path
## is on is a no-op.
func walk_to(point: Vector3) -> void:
	if body.pose == DoctorBody.Pose.DYING or body.is_dropping():
		return
	if is_instance_valid(path_follower):
		var follower_goal := path_follower.goal
		if (
			_walking
			and path_follower.is_active()
			and (
				Vector2(point.x - follower_goal.x, point.z - follower_goal.z).length()
				< repath_goal_m
			)
		):
			return
		path_follower.go_to(point)
	else:
		begin_walk(point)


## One straight leg to `point` (what the PathFollower hands out, and what walk_to does without one).
func begin_walk(point: Vector3) -> void:
	if body.pose == DoctorBody.Pose.DYING or body.is_dropping():
		return
	goal = point
	_walking = true
	body.states.transition(&"Grounded")


## Forgets the waypoints of the path in course.
func cancel_path() -> void:
	if is_instance_valid(path_follower):
		path_follower.cancel()


## Gravity, the avoidance around the other bodies, the ground guard and move_and_slide, as UnitBody.
## `horizontal` is the wanted velocity on x/z.
func advance_on_ground(horizontal: Vector3, delta: float) -> void:
	if body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= gravity() * delta
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z
	# The engine's avoidance steers the body around the others; the step ends in _on_avoided, this same physics step.
	if body.is_obstacle() and avoidance.steer(body.velocity):
		return
	_finish_step()


## Seconds of the «hit floor» clip: how long it stays down after touching the ground.
func landing_s() -> float:
	if body.type == null:
		return 0.0
	var facts := body.type.clip_facts()
	return float(facts.frames(&"hit_floor")) / maxf(float(facts.fps(&"hit_floor")), 1.0)


func turn_toward(direction: Vector3, delta: float) -> void:
	body.rotation.y = rotate_toward(
		body.rotation.y, atan2(direction.x, direction.z), turn_rate * delta
	)


## The velocity (x, z) the avoidance gave back: the second half of the step of advance_on_ground.
static func gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _on_avoided(flat_velocity: Vector3) -> void:
	body.velocity.x = flat_velocity.x
	body.velocity.z = flat_velocity.z
	_finish_step()


func _finish_step() -> void:
	body.velocity = EdgeClamp.clamp_velocity(body, body.velocity, get_physics_process_delta_time())
	body.move_and_slide()
	if FallCheck.has_fallen(body):
		body.kill()
