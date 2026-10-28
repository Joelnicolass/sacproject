class_name BodyCollider
extends Node

## The only writer of the physics capsule of a creature, a wizard and a doctor. The capsule is derived data, a pure function of
## the body scene it wears (BodyMount) and of whether Flight has it in the air: the ground capsule of the scene, or its flying one.
## It refits whenever either input changes, in any order (spawn, replication, a late join), and does nothing when nothing changed.
## A child of unit.tscn, wizard_body.tscn and doctor.tscn; the bodies and Flight never touch the shape.
## What it does not do: choose the body scene (BodyMount) or measure anything (the capsule is saved in the scene, ready to drag).

## Which body is worn; its facts hold the capsule sizes.
@export var mount: BodyMount
## The shape it sizes.
@export var collision: CollisionShape3D
## Optional: without it the body always has its ground capsule.
@export var flight: Flight


func _ready() -> void:
	if mount != null:
		mount.worn.connect(_on_worn)
	if flight != null:
		flight.state_changed.connect(_on_flight_changed)
	refit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if mount == null:
		warnings.append("Missing the worn body (mount).")
	if collision == null:
		warnings.append("Missing the capsule (collision).")
	return warnings


## Sizes the capsule for the body that is worn and the flight state now. Idempotent.
func refit() -> void:
	if mount == null or collision == null or not mount.is_worn():
		return
	var facts := mount.facts
	var radius := facts.capsule_radius_m
	var height := facts.capsule_height_m
	if flight != null and flight.is_airborne():
		height = facts.flying_capsule_height_m
	var capsule := collision.shape as CapsuleShape3D
	if (
		capsule != null
		and is_equal_approx(capsule.height, height)
		and is_equal_approx(capsule.radius, radius)
		and is_equal_approx(collision.position.y, height * 0.5)
	):
		return
	# A capsule saved in a scene (it has a resource path) is shared by every instance: copied once, then owned. A new one is sized
	# before it is assigned, so the physics server gets one shape update, not three.
	var fresh := capsule == null or not capsule.resource_path.is_empty()
	if fresh:
		capsule = CapsuleShape3D.new()
	capsule.height = height
	capsule.radius = radius
	capsule.height = height
	if fresh:
		collision.shape = capsule
	collision.position = Vector3(0.0, height * 0.5, 0.0)


func _on_worn(_facts: BodyFacts) -> void:
	refit()


func _on_flight_changed(_state: Flight.State) -> void:
	refit()
