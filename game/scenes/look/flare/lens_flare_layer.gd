class_name LensFlareLayer
extends LookLayer

## The camera's lens flare over the whole frame (lens_flare.gdshader): what shines most (the sun,
## the sky by it) throws ghosts, a halo and a starburst across the screen. `screen` is a 2 x 2
## quad the shader stretches over the screen. The quality preset turns it off
## (`LookQuality.lens_flare`). Presentation only.

@export var screen: MeshInstance3D


func _ready() -> void:
	if screen != null:
		screen.extra_cull_margin = 16384.0


func apply_quality(preset: LookQuality) -> void:
	visible = preset == null or preset.lens_flare
