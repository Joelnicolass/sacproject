@tool
class_name EnvironmentLayer
extends LookLayer

## Environment layer of the rig: the only writer of the map's Environment and of its sky. From the
## profile it draws the sky, the ambient light and reflections, the fog (and the `fx_fog_*` globals
## the additive sprites fade with, through LookGlobals), tonemapper, exposure, screen-space light
## and glow; the atmosphere's sample (night, weather) bends the ambient, the fog and the sky. It
## works on private copies of the shared `env_base.tres` and of the SkyLook's material and
## recomputes all of it from (profile, quality preset, visible, sample) every time: nothing is saved
## or restored. Hidden or without a profile it shows the base as it is. Presentation only: freed in
## a headless or dedicated process.

@export var world_environment: WorldEnvironment
## The rig's atmosphere layer. Empty = always the approved look.
@export var atmosphere: Atmosphere

@export_group("Compatibility (web)")
## WebGL 2 lights the same scene darker and more saturated than Forward+ (no volumetric haze, no sky
## reflections on the ground): the exposure and the saturation of every look are scaled there so
## the web reads like the desktop. Measured on a High Noon top view (models and ground).
@export_range(0.5, 4.0, 0.05) var compat_exposure_gain := 2.0
@export_range(0.0, 2.0, 0.01) var compat_saturation_gain := 0.8

var _profile: LookProfile
var _preset: LookQuality
var _base: Environment
var _env: Environment
var _sky: Sky
var _sky_dresser := SkyDresser.new()
var _watched: Array[Resource] = []
var _sky_retry := false
## The player's «Arte» values, written over everything else (ArtPrefs).
var _art: ArtPrefs


func _ready() -> void:
	_base = world_environment.environment if world_environment else null
	visibility_changed.connect(_refresh)
	if not Engine.is_editor_hint():
		_art = ArtPrefs.shared()
		if _art:
			_art.changed.connect(_on_art_changed)
	if atmosphere:
		atmosphere.changed.connect(_on_atmosphere_changed)


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
	if (
		Engine.is_editor_hint()
		and what == NOTIFICATION_EDITOR_PRE_SAVE
		and world_environment
		and _base
	):
		world_environment.environment = _base
	elif Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_POST_SAVE:
		_refresh()


## Editing a SkyLook (or its material), LightLook or GlowLook in the inspector refreshes the
## preview.
func _watch_parts() -> void:
	for resource in _watched:
		if is_instance_valid(resource) and resource.changed.is_connected(_refresh):
			resource.changed.disconnect(_refresh)
	_watched.clear()
	var parts: Array = (
		[
			_profile.sky,
			_profile.light,
			_profile.glow,
			_profile.sky.material if _profile.sky else null
		]
		if _profile
		else []
	)
	for resource: Resource in parts:
		if resource:
			resource.changed.connect(_refresh)
			_watched.append(resource)


func _refresh() -> void:
	if world_environment == null:
		return
	if _profile == null or _profile.sky == null or not is_visible_in_tree():
		world_environment.environment = _base
		LookGlobals.clear_fx_fog()
		return
	_env = _env if _env else (_base.duplicate() if _base else Environment.new())
	world_environment.environment = _env
	_write_sky(_profile.sky)
	_sky_dresser.reset()  # a full refresh copies the sky material again (it may have been edited)
	_write_atmosphere(true)
	_env.adjustment_color_correction = _profile.grade
	if _profile.glow:
		_profile.glow.write_to(_env, _preset == null or _preset.glow_enabled)
	else:
		_env.glow_enabled = false
	if _art:
		_art.apply_environment(_env)


# A value the player cleared must go back to the base: a fresh copy, then everything again.
func _on_art_changed() -> void:
	_env = null
	_refresh()


func _on_atmosphere_changed(_sample: AtmosphereSample) -> void:
	if _env and world_environment.environment == _env:
		_write_atmosphere(false)


# The sky held a sample back (rate limit): dress it again once the limit allows, so the last change
# always reaches the sky even when no other change follows.
func _retry_sky(sky_hz: float) -> void:
	if _sky_retry or not is_inside_tree():
		return
	_sky_retry = true
	await get_tree().create_timer(1.0 / maxf(sky_hz, 0.1)).timeout
	_sky_retry = false
	_on_atmosphere_changed(null)


## The parts the atmosphere bends: fog and light every time; the sky at most `atmosphere.sky_hz`
## (its cubemap re-bakes).
func _write_atmosphere(force_sky: bool) -> void:
	var sample := atmosphere.current() if atmosphere else AtmosphereSample.neutral()
	_write_fog(_profile.sky, sample)
	if _profile.light:
		_write_light(_profile.light, sample)
	var day := MatchSky.day_of(_profile.day)
	var moon := day.moon_dir_deg(_profile.light) if day and _profile.light else Vector2.ZERO
	var sky_hz := atmosphere.sky_hz if atmosphere else 2.0
	if not _sky_dresser.dress(_sky, _profile.sky, sample, moon, sky_hz, force_sky):
		_retry_sky(sky_hz)
	# The atmosphere rewrites fog and light every change: the player's values stay on top.
	if _art and not force_sky:
		_art.apply_environment(_env)


func _write_sky(look: SkyLook) -> void:
	if _sky == null:
		_sky = Sky.new()
		# the shader reads TIME: Automatic would rebake the cubemap every frame
		_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	_sky.radiance_size = look.radiance_size
	_env.background_mode = Environment.BG_SKY
	_env.sky = _sky
	_env.ambient_light_source = (
		Environment.AMBIENT_SOURCE_SKY
		if look.ambient_sky_contribution > 0.0
		else Environment.AMBIENT_SOURCE_COLOR
	)
	_env.ambient_light_sky_contribution = look.ambient_sky_contribution
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _write_fog(look: SkyLook, sample: AtmosphereSample) -> void:
	var fog_on := look.fog_enabled and (_preset == null or _preset.fog_enabled)
	_env.fog_enabled = fog_on
	_env.volumetric_fog_enabled = (
		(_base == null or _base.volumetric_fog_enabled)
		and (_preset == null or _preset.volumetric_fog_enabled)
	)
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = AtmosphereRules.fog_color(look, sample)
	_env.fog_density = look.fog_density * sample.fog_density
	var span := AtmosphereRules.fog_range(look, sample)
	_env.fog_depth_begin = span.x
	_env.fog_depth_end = span.y
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = look.fog_aerial_perspective
	_env.volumetric_fog_albedo = look.haze_tint
	_env.volumetric_fog_density = look.volumetric_density
	_env.volumetric_fog_length = look.volumetric_length_m
	LookGlobals.publish_fx_fog(
		_env.fog_density if fog_on else 0.0, _env.fog_depth_begin, _env.fog_depth_end
	)


func _write_light(look: LightLook, sample: AtmosphereSample) -> void:
	_env.ambient_light_color = look.ambient_color * sample.ambient_tint
	# a storm flash lights it
	_env.ambient_light_energy = look.ambient_energy * sample.ambient_energy * (1.0 + sample.flash)
	_env.tonemap_mode = look.tonemap_mode
	_env.tonemap_exposure = look.tonemap_exposure
	_env.tonemap_white = look.tonemap_white
	_env.adjustment_enabled = true
	_env.adjustment_saturation = look.saturation
	if InstanceParams.is_compat():
		_env.tonemap_exposure *= compat_exposure_gain
		_env.adjustment_saturation *= compat_saturation_gain
	_env.ssao_enabled = _preset.ssao_enabled if _preset else true
	_env.ssao_radius = look.ssao_radius
	_env.ssao_intensity = look.ssao_intensity
	_env.ssao_power = look.ssao_power
	_env.ssao_detail = look.ssao_detail
	_env.ssao_light_affect = look.ssao_light_affect
	_env.ssil_enabled = _preset.ssil_enabled if _preset else false
	_env.ssil_radius = look.ssil_radius
	_env.ssil_intensity = look.ssil_intensity


func _get_configuration_warnings() -> PackedStringArray:
	var missing: Array = [] if world_environment else ["The World Environment socket is missing."]
	return PackedStringArray(
		(
			missing
			+ (
				[]
				if atmosphere
				else [
					# gdlint: ignore=max-line-length
					"Without the Atmosphere socket the environment follows neither the hour nor the weather."
				]
			)
		)
	)
