@tool
class_name BodyVisual
extends MeshInstance3D

## What draws a creature, a wizard or the doctor: the skeleton of an animated body is drawn by its BodyRig (`rig`) and has no mesh
## here, a hybrid's static mesh is this node's own mesh (draw_look). Feet on local y = 0.
## This node owns its mesh and its transform (the look): the editor saves neither.
## To place a body, move a parent Node3D, not this node.

## Built from the look on every load, so the editor must not write them to the scene.
const _UNSAVED: PackedStringArray = ["mesh", "transform"]
const _LOCKED: PackedStringArray = ["mesh", "position", "rotation", "scale"]

## The skeletal body (BodyRig, RFC-023 023c) that hangs under this node and draws instead of the static mesh. It inherits
## this node's transform (the pose, the capsule scale, DevourGrowth). Set by the body's clip animator; null otherwise.
@export var rig: BodyRig
## The body scene this visual draws (BodyMount of the creature, wizard or doctor): `body_height` and `body_radius` come from there.
@export var mount: BodyMount

## A BodyLook draws this body (a creature or a wizard): `_ready` leaves the mesh and the transform alone from then on.
var _look_drawn := false


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint():
		if _UNSAVED.has(property.name):
			property.usage &= ~PROPERTY_USAGE_STORAGE
		if _LOCKED.has(property.name):
			property.usage |= PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	if not _look_drawn:
		transform = Transform3D.IDENTITY


## The look of a creature or wizard decides what this node shows: with a model the rig draws and this node's mesh goes away; a hybrid
## (no model) shows its static mesh here, in the pose of the look. Called by whoever listens to the rig (BodyAnimator).
func draw_look(look: BodyLook) -> void:
	_look_drawn = true
	var skeletal := look.has_model()
	mesh = null if skeletal else look.static_mesh
	if not skeletal:
		transform = look.transform


## GeometryInstance3D.transparency of the whole body, rig included (it does not inherit): summoning, play dead, stealth.
func set_fade(value: float) -> void:
	transparency = value
	if rig != null:
		rig.set_fade(value)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if mount == null:
		warnings.append("Asigná `mount` (el BodyMount del cuerpo): de ahí salen la altura y el radio.")
	return warnings


## The real height of the body (its footprint), before the capsule floor.
func body_height() -> float:
	return (mount.facts if mount != null else BodyFacts.fallback()).height_m


## Half the width of the body (the raw radius of its footprint).
func body_radius() -> float:
	return (mount.facts if mount != null else BodyFacts.fallback()).radius_m
