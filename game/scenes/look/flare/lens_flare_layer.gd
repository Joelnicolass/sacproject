class_name LensFlareLayer
extends LookLayer

## The camera's lens flare over the whole frame (lens_flare.gdshader): what shines most (the sun,
## the sky by it) throws ghosts, a halo and a starburst across the screen. `screen` is a 2 x 2
## quad the shader stretches over the screen. The quality preset turns it off
## (`LookQuality.lens_flare`); the player's «Arte» values (ArtPrefs.flare) go over its own.
## Presentation only.

const GROUP := &"lens_flare_layer"

@export var screen: MeshInstance3D

var _material: ShaderMaterial
## The flare's own values, so a value the player clears goes back to them.
var _own := {}


func _ready() -> void:
	add_to_group(GROUP)
	if screen != null:
		screen.extra_cull_margin = 16384.0
		_material = screen.get_active_material(0) as ShaderMaterial
	if _material != null and not Engine.is_editor_hint():
		for uniform in _material.shader.get_shader_uniform_list():
			_own[uniform["name"]] = _material.get_shader_parameter(uniform["name"])
		ArtPrefs.shared().changed.connect(_apply_art)
		_apply_art()


## The material the flare draws with (the «Arte» tab reads its uniforms).
func flare_material() -> ShaderMaterial:
	return _material


func _apply_art() -> void:
	for property: String in _own:
		_material.set_shader_parameter(property, _own[property])
	ArtPrefs.shared().apply_flare(_material)


func apply_quality(preset: LookQuality) -> void:
	visible = preset == null or preset.lens_flare
