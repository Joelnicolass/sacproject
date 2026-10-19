@tool
class_name LightLayer
extends LookLayer

## Light layer of the rig: puts the biome's `LightLook` on the map's sun and Environment, aims
## the fill light, and applies the preset's shadow splits / SSAO / SSIL. Switching the layer off
## (hide the node) or handing it a null profile puts the classic values back. Never edits the
## shared env_base.tres: it works on a copy. Nothing it computes is saved in a scene.

const SUN_PROPS: Array[StringName] = [
	&"transform", &"light_color", &"light_energy", &"light_angular_distance", &"light_volumetric_fog_energy", &"shadow_opacity",
	&"shadow_bias", &"shadow_normal_bias", &"shadow_blur", &"directional_shadow_mode",
	&"directional_shadow_max_distance", &"directional_shadow_split_1", &"directional_shadow_split_2",
	&"directional_shadow_split_3", &"directional_shadow_blend_splits", &"directional_shadow_fade_start"]
const ENV_PROPS: Array[StringName] = [
	&"ambient_light_color", &"ambient_light_energy", &"tonemap_exposure", &"tonemap_white",
	&"adjustment_enabled", &"adjustment_saturation", &"ssao_enabled", &"ssao_radius",
	&"ssao_intensity", &"ssao_power", &"ssao_detail", &"ssao_light_affect", &"ssil_enabled",
	&"ssil_radius", &"ssil_intensity", &"volumetric_fog_density", &"volumetric_fog_length"]
## ThemeApplier rewrites these on every apply, so they are re-read, not restored, on a new profile.
const THEME_PROPS: Array[StringName] = [
	&"light_color", &"light_energy", &"ambient_light_color", &"ambient_light_energy"]

## The fill light (a `fill_light.tscn`): no shadow, no specular.
@export var fill: DirectionalLight3D

var _rig: LookRig
var _look: LightLook
var _preset: LookQuality
var _sun_base := {}
var _env_base := {}
var _source_env: Environment
var _applied := false


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_rig = rig
	_preset = rig.quality_preset
	_look = profile.light as LightLook if profile else null
	# ThemeApplier rewrote the classic color/energy just before this call: re-read them.
	_refresh(true, _look != null)


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	if _applied:
		_refresh(false, true)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	# The editor preview must not end up in the saved scene.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_restore()
	elif what == NOTIFICATION_EDITOR_POST_SAVE and _look != null:
		_refresh(false, true)


func _on_visibility_changed() -> void:
	_refresh(false, true)


## `fresh_theme`: ThemeApplier just rewrote the classic values (new profile), so the baseline
## takes them; otherwise the saved baseline keeps them. `theme_values_too`: whether turning off
## writes those back (not when ThemeApplier already wrote the classic ones).
func _refresh(fresh_theme: bool, theme_values_too: bool) -> void:
	var sun := _rig.sun if _rig else null
	var world_env := _rig.world_environment if _rig else null
	if _look == null or not is_visible_in_tree() or sun == null or world_env == null:
		_restore(theme_values_too)
		return
	if _applied:
		# Back to the baseline the theme left, so a new look starts from the classic values.
		_write(sun, _sun_base, false)
		_write(world_env.environment, _env_base, false)
	else:
		_take_environment(world_env)
		fresh_theme = true
	_sun_base = _capture(sun, SUN_PROPS, _sun_base, fresh_theme)
	_env_base = _capture(world_env.environment, ENV_PROPS, _env_base, fresh_theme)
	_applied = true
	_apply_sun(sun)
	_apply_environment(world_env.environment)
	_apply_fill()


func _take_environment(world_env: WorldEnvironment) -> void:
	if world_env.environment == null:
		world_env.environment = Environment.new()
	# env_base.tres is shared: edit a copy (ThemeApplier already hands over a private one).
	if world_env.environment.resource_path != "":
		_source_env = world_env.environment
		world_env.environment = world_env.environment.duplicate()


func _restore(theme_values_too := true) -> void:
	if not _applied or _rig == null:
		return
	_applied = false
	if fill:
		fill.visible = false
	if is_instance_valid(_rig.sun):
		_write(_rig.sun, _sun_base, theme_values_too)
	var world_env := _rig.world_environment
	if is_instance_valid(world_env):
		if _source_env != null:
			world_env.environment = _source_env
		elif world_env.environment != null:
			_write(world_env.environment, _env_base, theme_values_too)
	_source_env = null


func _apply_sun(sun: DirectionalLight3D) -> void:
	var dir := _look.sun_direction()
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	sun.light_color = _look.sun_color
	sun.light_energy = _look.sun_energy
	sun.light_angular_distance = _look.sun_angular_distance
	sun.light_volumetric_fog_energy = _look.sun_fog_energy
	sun.shadow_opacity = _look.shadow_opacity
	sun.shadow_bias = _look.shadow_bias
	sun.shadow_normal_bias = _look.shadow_normal_bias
	sun.shadow_blur = _look.shadow_blur
	sun.directional_shadow_mode = _preset.shadow_splits if _preset else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var distance := _look.shadow_max_distance
	if _preset and _preset.shadow_distance_cap > 0.0:
		distance = minf(distance, _preset.shadow_distance_cap)
	sun.directional_shadow_max_distance = distance
	sun.directional_shadow_split_1 = _look.split_1
	sun.directional_shadow_split_2 = _look.split_2
	sun.directional_shadow_split_3 = _look.split_3
	sun.directional_shadow_blend_splits = _look.blend_splits
	sun.directional_shadow_fade_start = _look.fade_start


func _apply_environment(env: Environment) -> void:
	env.ambient_light_color = _look.ambient_color
	env.ambient_light_energy = _look.ambient_energy
	env.tonemap_exposure = _look.tonemap_exposure
	env.tonemap_white = _look.tonemap_white
	env.adjustment_enabled = true
	env.adjustment_saturation = _look.saturation
	env.ssao_enabled = _preset.ssao_enabled if _preset else true
	env.ssao_radius = _look.ssao_radius
	env.ssao_intensity = _look.ssao_intensity
	env.ssao_power = _look.ssao_power
	env.ssao_detail = _look.ssao_detail
	env.ssao_light_affect = _look.ssao_light_affect
	env.ssil_enabled = _preset.ssil_enabled if _preset else false
	env.ssil_radius = _look.ssil_radius
	env.ssil_intensity = _look.ssil_intensity
	env.volumetric_fog_density = _look.volumetric_density
	env.volumetric_fog_length = _look.volumetric_length


func _apply_fill() -> void:
	if fill == null:
		return
	fill.visible = true
	fill.basis = Basis.looking_at(-_look.fill_direction(), Vector3.UP)
	fill.light_color = _look.fill_color
	fill.light_energy = _look.fill_energy


static func _capture(node: Object, props: Array[StringName], old: Dictionary, fresh_theme: bool) -> Dictionary:
	var values := {}
	for prop in props:
		values[prop] = old[prop] if not fresh_theme and THEME_PROPS.has(prop) else node.get(prop)
	return values


## Writes saved values back; `theme_too` false skips the ones ThemeApplier owns.
static func _write(node: Object, values: Dictionary, theme_too: bool) -> void:
	if node == null:
		return
	for prop in values:
		if theme_too or not THEME_PROPS.has(prop):
			node.set(prop, values[prop])


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if fill == null:
		warnings.append("Falta el socket Fill (un fill_light.tscn).")
	return warnings
