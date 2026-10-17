@tool
class_name BodyPoseOverride
extends Resource

## One hand correction for one baked model: turn, offset, scale and capsule.
## Lives in data/bodies/pose_overrides.tres, which is committed. A new bake does not touch it.
## BodyCatalog adds it on top of what tools/bake_bodies.gd measured.

## Model tag (eorc, jnwr, pcfn...).
@export var model := "":
	set(value):
		model = value
		emit_changed()
## Degrees, added to the baked turn. The posed model faces +Z.
@export var rotation_degrees := Vector3.ZERO:
	set(value):
		rotation_degrees = value
		emit_changed()
## Meters, in the model's local space. y > 0 lifts it off the ground.
@export var position_offset := Vector3.ZERO:
	set(value):
		position_offset = value
		emit_changed()
@export var model_scale := Vector3.ONE:
	set(value):
		model_scale = value
		emit_changed()

@export_group("Cápsula")
## Meters. 0 uses the baked height (scaled with the model).
@export_range(0.0, 20.0, 0.01, "or_greater") var capsule_height := 0.0:
	set(value):
		capsule_height = value
		emit_changed()
## Meters, while a hybrid flier is up (Flight FLYING; F135, RFC-030e2b). The fly clip spreads wings and necks above
## the rest pose. 0 uses capsule_height (or the baked height). The radius does not change in the air.
@export_range(0.0, 20.0, 0.01, "or_greater") var capsule_height_flying := 0.0:
	set(value):
		capsule_height_flying = value
		emit_changed()
## Meters. 0 uses the baked radius (scaled with the model).
@export_range(0.0, 10.0, 0.01, "or_greater") var capsule_radius := 0.0:
	set(value):
		capsule_radius = value
		emit_changed()
## Meters, melee reach. 0 uses the baked one (scaled with the model).
@export_range(0.0, 20.0, 0.01, "or_greater") var reach := 0.0:
	set(value):
		reach = value
		emit_changed()

@export_group("Reposo")
## The rest clip (pose_source) floats on purpose: its frames only touch the ground at the bottom of the beat
## (Phoenix). tools/audit_body_pose.gd then judges the lowest point of the clip, not its median.
@export var rest_hovers := false:
	set(value):
		rest_hovers = value
		emit_changed()

@export_group("")
## Why this correction exists. Free text for whoever opens the file next.
@export_multiline var note := ""


func _validate_property(property: Dictionary) -> void:
	if property.name != "model":
		return
	var tags := BodyCatalog.models()
	if tags.is_empty():
		return
	tags.sort()
	if not model.is_empty() and not tags.has(model):
		tags.append(model)
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(tags)
