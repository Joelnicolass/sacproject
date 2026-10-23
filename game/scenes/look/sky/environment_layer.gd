@tool
class_name EnvironmentLayer
extends LookLayer

## Environment layer of the rig: the only writer of the map's Environment. From the profile it draws the sky,
## the ambient light and reflections, the fog (and the `fx_fog_*` shader globals the additive sprites fade with),
## tonemapper, exposure, screen-space light and glow. It works on a private copy of the shared `env_base.tres` and
## recomputes all of it from (profile, quality preset, visible) every time: nothing is saved or restored, and hidden
## or without a profile it shows the base as it is. Presentation only: freed in a headless or dedicated process.

@export var world_environment: WorldEnvironment

var _profile: LookProfile
var _preset: LookQuality
var _base: Environment
var _env: Environment
var _sky: Sky
var _watched: Array[Resource] = []


func _ready() -> void:
	_base = world_environment.environment if world_environment else null
	visibility_changed.connect(_refresh)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_profile = profile
	_preset = rig.quality_preset
	_watch_parts()
	_refresh()


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	_refresh()


func _notification(what: int) -> void:
	# The preview is a private copy: the saved scene keeps pointing at the shared base.
	if Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_PRE_SAVE and world_environment and _base:
		world_environment.environment = _base
	elif Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_POST_SAVE:
		_refresh()


## Editing a SkyLook, LightLook or GlowLook in the inspector refreshes the preview.
func _watch_parts() -> void:
	for resource in _watched:
		if is_instance_valid(resource) and resource.changed.is_connected(_refresh):
			resource.changed.disconnect(_refresh)
	_watched.clear()
	for resource: Resource in [_profile.sky, _profile.light, _profile.glow] if _profile else []:
		if resource:
			resource.changed.connect(_refresh)
			_watched.append(resource)


func _refresh() -> void:
	if world_environment == null:
		return
	if _profile == null or _profile.sky == null or not is_visible_in_tree():
		world_environment.environment = _base
		_publish_fx_fog(null)
		return
	_env = _env if _env else (_base.duplicate() if _base else Environment.new())
	world_environment.environment = _env
	_write_sky(_profile.sky)
	_write_fog(_profile.sky)
	if _profile.light:
		_write_light(_profile.light)
	_env.adjustment_color_correction = _profile.grade
	_write_glow(_profile.glow)


func _write_sky(look: SkyLook) -> void:
	if _sky == null:
		_sky = Sky.new()
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY  # the shader reads TIME: Automatic would rebake the cubemap every frame
	_sky.sky_material = look.material
	_sky.radiance_size = look.radiance_size
	_env.background_mode = Environment.BG_SKY
	_env.sky = _sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if look.ambient_sky_contribution > 0.0 else Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_sky_contribution = look.ambient_sky_contribution
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _write_fog(look: SkyLook) -> void:
	_env.fog_enabled = look.fog_enabled
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = look.fog_color
	_env.fog_density = look.fog_density
	_env.fog_depth_begin = look.fog_begin_m
	_env.fog_depth_end = look.fog_end_m
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = look.fog_aerial_perspective
	_env.volumetric_fog_albedo = look.haze_tint
	_env.volumetric_fog_density = look.volumetric_density
	_env.volumetric_fog_length = look.volumetric_length_m
	_publish_fx_fog(look)


func _write_light(look: LightLook) -> void:
	_env.ambient_light_color = look.ambient_color
	_env.ambient_light_energy = look.ambient_energy
	_env.tonemap_mode = look.tonemap_mode
	_env.tonemap_exposure = look.tonemap_exposure
	_env.tonemap_white = look.tonemap_white
	_env.adjustment_enabled = true
	_env.adjustment_saturation = look.saturation
	_env.ssao_enabled = _preset.ssao_enabled if _preset else true
	_env.ssao_radius = look.ssao_radius
	_env.ssao_intensity = look.ssao_intensity
	_env.ssao_power = look.ssao_power
	_env.ssao_detail = look.ssao_detail
	_env.ssao_light_affect = look.ssao_light_affect
	_env.ssil_enabled = _preset.ssil_enabled if _preset else false
	_env.ssil_radius = look.ssil_radius
	_env.ssil_intensity = look.ssil_intensity


func _write_glow(glow: GlowLook) -> void:
	_env.glow_enabled = glow != null and glow.enabled and (_preset == null or _preset.glow_enabled)
	if glow == null:
		return
	_env.glow_intensity = glow.intensity
	_env.glow_strength = glow.strength
	_env.glow_bloom = glow.bloom
	_env.glow_hdr_threshold = glow.hdr_threshold
	_env.glow_hdr_scale = glow.hdr_scale
	_env.glow_blend_mode = glow.blend_mode
	for i in mini(glow.levels.size(), 7):
		_env.set_glow_level(i, glow.levels[i])


## The additive sprites keep `fog_disabled` (Godot would add the fog's light to them) and fade with the same
## depth fog through these shader globals, written next to the Environment so both always agree.
static func _publish_fx_fog(look: SkyLook) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.global_shader_parameter_set(&"fx_fog_density", look.fog_density if look and look.fog_enabled else 0.0)
	RenderingServer.global_shader_parameter_set(&"fx_fog_begin", look.fog_begin_m if look else 0.0)
	RenderingServer.global_shader_parameter_set(&"fx_fog_end", look.fog_end_m if look else 1.0)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if world_environment == null:
		warnings.append("Falta el socket World Environment.")
	return warnings
