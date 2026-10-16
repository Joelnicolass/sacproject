@tool
class_name GroundLayer
extends Resource

## One ground material of a biome: its three maps, how it is tiled, and where it shows. A new
## ground texture is a new `.tres` of this type, dragged into a `GroundSet`; no code changes.
## Maps: albedo (sRGB), normal (OpenGL: green up) and ORM (R = ambient occlusion, G = roughness,
## B = height, used to blend layers). The packing is in assets/cc0/LICENSES.md.

@export var label: String = ""

@export_group("Maps")
@export var albedo: Texture2D
@export var normal: Texture2D
@export var orm: Texture2D

@export_group("Mapping")
## Size of one texture repeat on the ground, in meters.
@export_range(0.25, 32.0, 0.05, "suffix:m") var uv_scale_m := 2.0
@export var tint := Color.WHITE
@export_range(0.0, 2.0, 0.01) var normal_strength := 1.0
## Added to the roughness map (some scans are glossier than they look in the sun).
@export_range(-0.8, 0.8, 0.01) var roughness_offset := 0.0
## How much this layer's height map pushes it over the layers below at a blend edge.
@export_range(0.0, 2.0, 0.01) var height_contrast := 0.6
## Weight multiplier before the blend: above 1 the layer wins over its neighbors at patch edges.
@export_range(0.2, 4.0, 0.05) var priority := 1.0
## Projects the maps from three sides, so a cliff does not stretch. Use it on rock.
@export var triplanar := false
## Breaks the repetition with two offset taps (high preset only; 2x the cost of the layer).
@export var stochastic := true

@export_group("Rules")
## Where the layer shows by slope of the ground, in degrees (0 flat, 90 a wall).
@export_range(0.0, 90.0, 0.5, "suffix:deg") var slope_min_deg := 0.0
@export_range(0.0, 90.0, 0.5, "suffix:deg") var slope_max_deg := 90.0
## Width of the soft edge of the slope range.
@export_range(0.5, 40.0, 0.5, "suffix:deg") var slope_soft_deg := 6.0
## Where the layer shows by height above the map's zero, in meters.
@export_range(-200.0, 200.0, 0.5, "suffix:m") var altitude_min_m := -200.0
@export_range(-200.0, 200.0, 0.5, "suffix:m") var altitude_max_m := 200.0
@export_range(0.5, 60.0, 0.5, "suffix:m") var altitude_soft_m := 8.0
## How much the original map's zones decide: 0 = the layer shows anywhere its slope and height
## rules allow, 1 = only inside the zone the TileLayerMap gives it.
@export_range(0.0, 1.0, 0.01) var tile_weight := 0.0
## Breaks the layer into patches with low-frequency noise: 0 = even, 1 = clear patches.
@export_range(0.0, 1.0, 0.01) var patchiness := 0.0
