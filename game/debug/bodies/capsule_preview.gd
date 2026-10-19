@tool
class_name CapsulePreview
extends MeshInstance3D

## Draws, as a translucent capsule, the body the game gives a BodyVisual: the same height and
## radius unit.tscn and wizard_body.tscn use for their CollisionShape3D, so a technical artist
## sees whether the model fits. It redraws when the model or pose_overrides.tres changes.
## This node owns its mesh and its position: the editor saves neither. Move the parent.

const _UNSAVED: PackedStringArray = ["mesh", "transform"]

## The BodyVisual whose capsule is drawn. Usually the sibling named Visual.
@export var visual: BodyVisual:
	set(value):
		if visual and visual.posed.is_connected(_refresh):
			visual.posed.disconnect(_refresh)
		visual = value
		if visual:
			visual.posed.connect(_refresh)
		_refresh()
@export var color := Color(0.25, 0.65, 1.0, 0.3):
	set(value):
		color = value
		_refresh()


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint() and _UNSAVED.has(property.name):
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _ready() -> void:
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	if visual == null:
		return PackedStringArray(["Asigná `visual`: el BodyVisual cuya cápsula se dibuja."])
	return PackedStringArray()


func _refresh() -> void:
	update_configuration_warnings()
	if visual == null:
		mesh = null
		return
	var height := maxf(visual.body_height(), 0.6)
	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = minf(visual.body_radius(), height * 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	capsule.material = material
	mesh = capsule
	# Same as the CollisionShape3D of the actors: centered half a height above the feet.
	transform = Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))
