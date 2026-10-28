class_name Locomotion
extends Node

## How a walking body moves in one physics step: gravity (or the lift of a flier), what its afflictions do to the velocity, the engine's
## avoidance, the turn toward where it really goes, the edge of the land, the slide and the fall into a hole. Units and wizards share it.
## Not: where to go (the states and the orders), when to step (the body calls `begin` and `finish` in its own order: this node never
## processes by itself) nor what a fall means (it only says `fell`).

## The slide is done: the body presents its pose.
signal moved
## The body is far below the land over a hole (it never fires while flying).
signal fell

@export var body: CharacterBody3D
@export var afflictions: Afflictions
## The engine's avoidance of this body; its `solved` signal is connected to `resume`.
@export var avoidance: BodyAvoidance
## The vertical half of a creature (UnitAir). Empty = plain gravity, as a wizard has.
@export var air: UnitAir
## A walking body faces the velocity it really has after the avoidance. A wizard turns by his own input instead.
@export var face_velocity := true
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
## Below this flat speed (m/s) a body keeps its facing.
@export var face_min_speed := 0.1

## Where a creature walks to (begin_walk); the Move state steers to it.
var goal := Vector3.ZERO
## The body flew when this step began (the avoidance ends the step later in it).
var airborne_step := false

var _walk_intent := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null or afflictions == null or avoidance == null:
		warnings.append("Assign body, afflictions and avoidance.")
	return warnings


## The vertical half of the step, and no flat speed yet (the caller sets it). `walking`: the creature is in MOVE.
func begin(delta: float, walking := false) -> void:
	if air != null:
		airborne_step = air.step_vertical(delta, walking)
	elif body.is_on_floor():
		body.velocity.y = 0.0
	else:
		body.velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	body.velocity.x = 0.0
	body.velocity.z = 0.0


## The rest of the step with the flat velocity the caller chose: afflictions, then the avoidance (the step ends in `resume`), else the
## slide at once. `may_walk` false: it does not face its velocity this step. `is_obstacle` is asked after the afflictions steered.
func finish(delta: float, may_walk: bool, is_obstacle: Callable) -> void:
	_steer(delta, may_walk)
	if is_obstacle.call() and avoidance.steer(body.velocity, afflictions.fixed()):
		return
	_slide()


## The same step as `finish` but the slide happens right here, for a body that moves inside the kit's `mp_move` (it runs again on the
## owner when it reconciles, so it cannot wait for the avoidance's answer). The others still steer around it: its velocity is announced.
func finish_now(delta: float, is_obstacle: Callable) -> void:
	_steer(delta, false)
	if is_obstacle.call():
		avoidance.announce(body.velocity, afflictions.fixed())
	_slide()


func _steer(delta: float, may_walk: bool) -> void:
	if air != null:
		air.hold_still()
	body.velocity = afflictions.steer(body.velocity, delta)
	_walk_intent = face_velocity and may_walk and not airborne_step and not afflictions.holds() and _flat_speed() > face_min_speed


## The velocity (x, z) the avoidance gave back: the second half of the step.
func resume(flat_velocity: Vector3) -> void:
	body.velocity.x = flat_velocity.x
	body.velocity.z = flat_velocity.z
	_slide()


func turn_toward(direction: Vector3, delta: float) -> void:
	var wanted := atan2(direction.x, direction.z)
	body.rotation.y = rotate_toward(body.rotation.y, wanted, turn_rate * delta)


func flat_distance(node: Node3D) -> float:
	var d := node.global_position - body.global_position
	return Vector2(d.x, d.z).length()


func _slide() -> void:
	var delta := body.get_physics_process_delta_time()
	# A ground creature faces where it really goes (avoidance may bend the wanted velocity); pushes never reach here.
	if _walk_intent and _flat_speed() > face_min_speed:
		turn_toward(Vector3(body.velocity.x, 0.0, body.velocity.z), delta)
	if air != null:
		air.cap_pace()
	if not airborne_step:
		body.velocity = EdgeClamp.clamp_velocity(body, body.velocity, delta)
	body.move_and_slide()
	if not airborne_step and FallCheck.has_fallen(body):
		fell.emit()
	moved.emit()


func _flat_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()
