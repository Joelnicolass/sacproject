@tool
class_name SunLayer
extends LookLayer

## Sun layer of the rig: the only writer of the map's sun and fill lights. From the biome's `LightLook`, the
## quality preset and the atmosphere's sample it aims them and sets color, energy, shadows and splits, all recomputed
## on every call. At night the same light is the moon (no second light, no pop: the day's energy is ~0 at the switch).
## Hiding the layer hides both lights (they are its children); a profile without light turns them off.
## Presentation only: the rig, and this layer with it, is freed in a headless or dedicated process.

## The map's sun: casts the shadows and is the sky's sun.
@export var sun: DirectionalLight3D
## The fill light (a `fill_light.tscn`): no shadow, no specular.
@export var fill: DirectionalLight3D
## The rig's atmosphere layer. Empty = always the approved light.
@export var atmosphere: Atmosphere

var _profile: LookProfile
var _preset: LookQuality


func _ready() -> void:
	if atmosphere:
		atmosphere.changed.connect(_on_atmosphere_changed)


func apply_look(profile: LookProfile, rig: LookRig) -> void:
	_profile = profile
	_preset = rig.quality_preset
	_refresh()


func apply_quality(preset: LookQuality) -> void:
	_preset = preset
	_refresh()


func _refresh() -> void:
	var look := _profile.light if _profile else null
	if sun:
		sun.visible = look != null
	if fill:
		fill.visible = look != null
	if look == null:
		return
	if sun:
		_write_sun(look)
	_write_atmosphere(look)


func _on_atmosphere_changed(_sample: AtmosphereSample) -> void:
	var look := _profile.light if _profile else null
	if look:
		_write_atmosphere(look)


## What the hour bends: where the light comes from (sun or moon), its color and energy, and the fill's.
func _write_atmosphere(look: LightLook) -> void:
	var sample := atmosphere.current() if atmosphere else AtmosphereSample.neutral()
	if sun:
		sun.basis = Basis.looking_at(-_light_direction(look, sample), Vector3.UP)
		sun.light_color = look.sun_color * sample.light_tint
		sun.light_energy = look.sun_energy * sample.light_energy
	if fill:
		fill.basis = Basis.looking_at(-look.fill_direction(), Vector3.UP)
		fill.light_color = look.fill_color * sample.ambient_tint
		fill.light_energy = look.fill_energy * sample.ambient_energy


func _light_direction(look: LightLook, sample: AtmosphereSample) -> Vector3:
	if sample.moon and _profile.day:
		var moon := _profile.day.moon_dir_deg(look)
		return LightLook.direction_of(moon.x, moon.y)
	if sample.elevation_change_deg == 0.0:
		return look.sun_direction()
	return LightLook.direction_of(look.sun_azimuth_deg, AtmosphereRules.light_elevation(look.sun_elevation_deg, sample))


func _write_sun(look: LightLook) -> void:
	sun.light_angular_distance = look.sun_angular_distance
	sun.light_volumetric_fog_energy = look.sun_fog_energy
	sun.shadow_opacity = look.shadow_opacity
	sun.shadow_bias = look.shadow_bias
	sun.shadow_normal_bias = look.shadow_normal_bias
	sun.shadow_blur = look.shadow_blur
	sun.directional_shadow_mode = _preset.shadow_splits if _preset else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var distance := look.shadow_max_distance
	if _preset and _preset.shadow_distance_cap > 0.0:
		distance = minf(distance, _preset.shadow_distance_cap)
	sun.directional_shadow_max_distance = distance
	sun.directional_shadow_split_1 = look.split_1
	sun.directional_shadow_split_2 = look.split_2
	sun.directional_shadow_split_3 = look.split_3
	sun.directional_shadow_blend_splits = look.blend_splits
	sun.directional_shadow_fade_start = look.fade_start


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if sun == null or fill == null:
		warnings.append("Faltan los sockets Sun / Fill.")
	return warnings
