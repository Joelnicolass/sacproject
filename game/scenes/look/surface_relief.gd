class_name SurfaceRelief
extends RefCounted

## Hands a surface's normal map to the ShaderMaterial copy that StoneLook or BuildReveal draws instead of it, so a petrified or
## rising body keeps its relief. The copy's shader includes surface_relief.gdshaderinc and calls relief_apply(UV).
## Not: when to petrify or reveal, nor any other parameter of the copy. A source with no normal map turns `use_relief` off,
## and the shader then draws exactly what it drew before (its normal is never touched).


static func forward(source: BaseMaterial3D, target: ShaderMaterial) -> void:
	var on := source != null and source.normal_enabled and source.normal_texture != null
	target.set_shader_parameter(&"use_relief", on)
	target.set_shader_parameter(&"relief_normal_tex", source.normal_texture if on else null)
	target.set_shader_parameter(&"relief_normal_scale", source.normal_scale if on else 1.0)
