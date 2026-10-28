@tool
class_name GrassPalette
extends Resource

## The colors and the material of a biome's grass, over one shared `GrassType` shape.
## A `GrassSet` with a palette draws its type with these values instead of the type's own; the type
## file is never changed (`GrassSet.resolved_type()` returns a runtime copy). Persephone has no
## palette: its colors live in `meadow.tres`. Edit a palette in the inspector with the world open
## and the field shows it live; edit `meadow.tres` and every biome changes.

@export_group("Color")
## Body and tip of the blade. The root is always the color of the ground under it.
@export var color_mid := Color(0.28, 0.55, 0.08)
@export var color_tip := Color(0.55, 0.8, 0.2)
## How much the body takes the color of the ground below (0 = only `color_mid`).
@export_range(0.0, 1.0, 0.01) var ground_mix := 0.1
## Strength of the color change from tuft to tuft.
@export_range(0.0, 1.0, 0.01) var clump_tint := 0.5
## How much the gusts lighten the tips.
@export_range(0.0, 1.0, 0.01) var gust_lighten := 0.35

@export_group("Light")
@export_range(0.0, 1.0, 0.01) var specular := 0.4
@export_range(0.05, 1.0, 0.01) var roughness := 0.55
@export_range(0.0, 1.0, 0.01) var translucency := 0.5
## Darkness at the root.
@export_range(0.0, 1.0, 0.01) var root_ao := 0.5

@export_group("Ground paint")
## How much the ground takes the field's average color where grass grows.
@export_range(0.0, 1.0, 0.01) var paint_amount := 0.9
## Brightness of that average against the plain mix of body and tip.
@export_range(0.3, 1.5, 0.01) var paint_tone := 1.7
## Strength of the pale wind bands on the painted ground.
@export_range(0.0, 1.0, 0.01) var paint_waves := 0.12


## Writes this palette over `type` (a runtime copy, never a file).
func apply_to(type: GrassType) -> void:
	type.color_mid = color_mid
	type.color_tip = color_tip
	type.ground_mix = ground_mix
	type.clump_tint = clump_tint
	type.gust_lighten = gust_lighten
	type.specular = specular
	type.roughness = roughness
	type.translucency = translucency
	type.root_ao = root_ao
	type.paint_amount = paint_amount
	type.paint_tone = paint_tone
	type.paint_waves = paint_waves
