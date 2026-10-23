@tool
class_name SunLayer
extends LookLayer

## Sun layer of the rig: the only writer of the map's sun and fill lights. From the biome's `LightLook` and the
## quality preset it aims them and sets color, energy, shadows and splits, all recomputed on every call.
## Hiding the layer hides both lights (they are its children); a profile without light turns them off.
## Presentation only: the rig, and this layer with it, is freed in a headless or dedicated process.

## The map's sun: casts the shadows and is the sky's sun.
@export var sun: DirectionalLight3D
## The fill light (a `fill_light.tscn`): no shadow, no specular.
@export var fill: DirectionalLight3D

var _profile: LookProfile
var _preset: LookQuality


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
	if fill:
		fill.basis = Basis.looking_at(-look.fill_direction(), Vector3.UP)
		fill.light_color = look.fill_color
		fill.light_energy = look.fill_energy


func _write_sun(look: LightLook) -> void:
	sun.basis = Basis.looking_at(-look.sun_direction(), Vector3.UP)
	sun.light_color = look.sun_color
	sun.light_energy = look.sun_energy
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
