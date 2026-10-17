class_name GodEnvi
extends Resource

## The ENVI record of one god's land (sacengine envi.d), as the colours Godot needs. One per god in
## assets/original/themes/<god>/envi.tres, written by tools/import_themes.py; GodTheme reads it.
## Colours are linear values (renderer.d setupEnvironment formulas), not sRGB.

@export var background_color: Color = Color(1.0, 0.706, 0.471)
@export var ambient_color: Color = Color(0.38, 0.4, 0.52)
@export var sun_color: Color = Color(1.0, 1.0, 1.0)
@export var fog_color: Color = Color(0.5, 0.55, 0.82)
@export var fog_begin: float = 100.0
@export var fog_end: float = 1600.0
## ENVI density, kept as the original stores it (the depth fog uses GodTheme.fog_density).
@export var fog_density: float = 0.0
@export var sun_direct_strength: float = 1.0
@export var sun_ambient_strength: float = 0.0
@export var shadow_strength: float = 0.0
@export var sun_direction: Vector3 = Vector3.ZERO
