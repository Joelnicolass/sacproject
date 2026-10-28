@tool
class_name SkyUnderside
extends LookLayer

## What is seen under the island through the void and through the pits: the look's `SkyLook.under_texture` on a wide plane
## far under the map (its `Plane` child, hidden until a look brings a picture: size, depth, brightness and turn are that node
## and its material, in the inspector). With no picture in the look the plane stays hidden and the sky shows below. It does not draw the sky's bands or clouds (the
## sky material, EnvironmentLayer) nor the walls under the rim (the ground shader). Presentation only.

## The plane; its material (sky_underside.gdshader) is the default: the look's picture goes on a private copy, never saved.
@export var plane: MeshInstance3D

var _material: ShaderMaterial
var _was_shown := false


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if plane
		else PackedStringArray(["The `plane` socket is missing (the background MeshInstance3D)."])
	)


func apply_look(profile: LookProfile, _rig: LookRig) -> void:
	if plane == null:
		return
	var look := profile.sky if profile else null
	var picture := look.under_texture if look else null
	if picture != null:
		if _material == null:
			_material = (plane.mesh.surface_get_material(0) as ShaderMaterial).duplicate()
		_material.set_shader_parameter(&"picture", picture)
	_show(picture != null)


func _show(shown: bool) -> void:
	plane.visible = shown
	plane.material_override = _material if shown else null


func _notification(what: int) -> void:
	# The look's picture is a preview in the editor: the saved scene keeps the plane as it is in sky_underside.tscn.
	if Engine.is_editor_hint() and plane and what == NOTIFICATION_EDITOR_PRE_SAVE:
		_was_shown = plane.visible
		plane.visible = false
		plane.material_override = null
	elif Engine.is_editor_hint() and plane and what == NOTIFICATION_EDITOR_POST_SAVE:
		_show(_was_shown and _material != null)
