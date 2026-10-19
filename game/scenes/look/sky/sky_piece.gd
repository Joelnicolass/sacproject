@tool
class_name SkyPiece
extends MeshInstance3D

## One sky pass over the original sky: a full-screen quad at the far plane with its own shader
## (the scene holds mesh and material, so the editor shows it with any camera). Hiding the node
## turns the piece off. Subclasses map a `SkyLook` onto their uniforms.


## `sun_dir`: unit vector from the ground toward the map's Sun.
func apply_sky(_look: SkyLook, _sun_dir: Vector3) -> void:
	pass


func _uniform(uniform: StringName, value: Variant) -> void:
	(material_override as ShaderMaterial).set_shader_parameter(uniform, value)
