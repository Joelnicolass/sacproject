class_name BodyCollider
extends Node

## F135 (RFC-030e2b): the only writer of the unit's capsule. The capsule is derived data, a pure function of
## (model, pose profile): BodyCatalog.info(model) height on the ground, height_flying while Flight is FLYING. It refits
## whenever either input changes, in any order (spawn, replication, a late join), and does nothing when nothing changed.
## A child of unit.tscn; UnitBody and Flight never touch the shape.
## RFC-023: when skeletal poses arrive, read the box of the current frame here instead of info() (sacobject.d:274-319).

## The body whose model sizes the capsule.
@export var body: UnitBody
## The shape it sizes.
@export var collision: CollisionShape3D
## Optional: without it the body always has its ground capsule.
@export var flight: Flight
## Optional: the visual's body_height/body_radius (its placeholder size when the model is not baked). Without it,
## BodyCatalog.info().
@export var visual: BodyVisual

const MIN_HEIGHT := 0.6
## Radius at most this fraction of the ground height.
const RADIUS_PER_HEIGHT := 0.45


func _ready() -> void:
	if body != null:
		body.model_changed.connect(refit)
		if not body.is_node_ready():
			body.ready.connect(refit, CONNECT_ONE_SHOT)
	if flight != null:
		flight.state_changed.connect(_on_flight_changed)
	refit()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	if collision == null:
		warnings.append("Falta la cápsula (collision).")
	return warnings


## Sizes the capsule for the body's model and the flight state now. Idempotent.
func refit() -> void:
	if body == null or collision == null or body.model.is_empty():
		return
	var info := BodyCatalog.info(body.model)
	var ground := float(visual.body_height()) if visual else float(info.get("height", 1.8))
	ground = maxf(ground, MIN_HEIGHT)
	var radius := minf(float(visual.body_radius()) if visual else float(info.get("radius", 0.35)), ground * RADIUS_PER_HEIGHT)
	var height := ground
	if flight != null and flight.is_airborne():
		height = maxf(float(info.get("height_flying", ground)), MIN_HEIGHT)
	var capsule := collision.shape as CapsuleShape3D
	if capsule != null and is_equal_approx(capsule.height, height) and is_equal_approx(capsule.radius, radius) \
			and is_equal_approx(collision.position.y, height * 0.5):
		return
	# The capsule saved in unit.tscn (it has a resource path) is shared by every instance: copied once, then owned.
	if capsule == null or not capsule.resource_path.is_empty():
		capsule = CapsuleShape3D.new()
		collision.shape = capsule
	capsule.height = height
	capsule.radius = radius
	capsule.height = height
	collision.position = Vector3(0.0, height * 0.5, 0.0)


func _on_flight_changed(_state: Flight.State) -> void:
	refit()
