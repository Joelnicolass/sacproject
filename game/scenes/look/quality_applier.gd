@tool
class_name QualityApplier
extends Node

## Applies a LookQuality to its viewport. With `quality` empty it does nothing, so the game
## renders as before until a preset is assigned. Presentation only: inert in a headless process.

@export var quality: LookQuality:
	set(value):
		quality = value
		if is_node_ready():
			apply()


func _ready() -> void:
	apply()


func apply() -> void:
	if quality == null or Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	apply_to(get_viewport(), quality)


static func apply_to(viewport: Viewport, preset: LookQuality) -> void:
	viewport.scaling_3d_mode = preset.scaling_mode
	viewport.scaling_3d_scale = preset.scale
	viewport.fsr_sharpness = preset.fsr_sharpness
	viewport.screen_space_aa = preset.screen_space_aa
	viewport.msaa_3d = preset.msaa_3d
	viewport.use_taa = false
	RenderingServer.directional_shadow_atlas_set_size(preset.shadow_atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset.shadow_filter)
	apply_fx_globals(preset)


## The sprite shaders read these globals (project.godot `shader_globals`), so a
## preset change does not rebuild the cached FxAtlas materials. Their project defaults are 0: until a
## preset is applied the sprites draw plain (hard edge, frames that jump).
static func apply_fx_globals(preset: LookQuality) -> void:
	RenderingServer.global_shader_parameter_set(&"fx_soft_particles", 1.0 if preset.fx_soft_particles else 0.0)
	RenderingServer.global_shader_parameter_set(&"fx_frame_blend", 1.0 if preset.fx_frame_blend else 0.0)


## What the viewport really holds now (an unsupported mode can fall back).
static func read_back(viewport: Viewport) -> Dictionary:
	return {
		"mode": viewport.scaling_3d_mode,
		"scale": viewport.scaling_3d_scale,
		"aa": viewport.screen_space_aa,
		"msaa": viewport.msaa_3d,
	}
