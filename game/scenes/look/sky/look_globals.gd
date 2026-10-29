class_name LookGlobals
extends RefCounted

## The one place that publishes the look's shader globals: the depth fog the additive sprites fade
## with (`fx_fog_density`, `fx_fog_begin`, `fx_fog_end`, declared in project.godot). Only
## EnvironmentLayer calls it, right after it writes the Environment's fog, so both always agree. It
## decides no value. Nothing in a headless process.


static func publish_fx_fog(density: float, begin_m: float, end_m: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.global_shader_parameter_set(&"fx_fog_density", density)
	RenderingServer.global_shader_parameter_set(&"fx_fog_begin", begin_m)
	RenderingServer.global_shader_parameter_set(&"fx_fog_end", end_m)


## No fog: the sprites do not fade.
static func clear_fx_fog() -> void:
	publish_fx_fog(0.0, 0.0, 1.0)
