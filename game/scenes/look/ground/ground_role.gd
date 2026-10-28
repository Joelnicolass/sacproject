@tool
class_name GroundRole
extends Resource

## What one kind of ground of a god looks like (open grass, earth, rock or path): its pictures, how big they are on the map and
## how it meets the others. Where each kind lies on a map is the map's `ground_roles.png`, not this. Lives embedded in a
## `GodGround`; editing it refreshes the editor preview.
## Albedo: a sheet of `variants_per_side` x `variants_per_side` tiles, one picked per 10 m cell (1 = one picture tiled every
## `tile_m`). Normal (OpenGL, green up) and ORM (R occlusion, G roughness, B height) are optional and follow the albedo layout.

@export_group("Maps")
## The colours as the land paints them (the shader lights them as flat ground).
@export var albedo: Texture2D:
	set(value):
		albedo = value
		emit_changed()
@export var normal: Texture2D:
	set(value):
		normal = value
		emit_changed()
@export var orm: Texture2D:
	set(value):
		orm = value
		emit_changed()
## The fine grey grain laid over the colour (stones, leaves, cracks); empty = none.
@export var detail: Texture2D:
	set(value):
		detail = value
		emit_changed()

@export_group("Layout")
## Tiles per side of the albedo sheet: 4 = 16 variants, one per 10 m cell; 1 = the albedo is one picture.
@export_range(1, 8) var variants_per_side := 4:
	set(value):
		variants_per_side = value
		emit_changed()
## Metres one tile (one variant) covers on the ground. 10 = one map cell.
@export_range(0.5, 40.0, 0.5, "suffix:m") var tile_m := 10.0:
	set(value):
		tile_m = value
		emit_changed()
## Multiplies the albedo (white = as painted).
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()

@export_group("Grain")
## 0 = no grain, 1 = full strength.
@export_range(0.0, 2.0, 0.01) var detail_strength := 1.0:
	set(value):
		detail_strength = value
		emit_changed()
## How many times the grain repeats inside one tile.
@export_range(1.0, 8.0, 1.0) var detail_repeat := 1.0:
	set(value):
		detail_repeat = value
		emit_changed()

@export_group("Relief")
@export_range(0.0, 2.0, 0.01) var normal_strength := 1.0:
	set(value):
		normal_strength = value
		emit_changed()
## How much the bright (high) parts of this ground poke through its neighbours at a border.
@export_range(0.0, 2.0, 0.01) var height_contrast := 0.6:
	set(value):
		height_contrast = value
		emit_changed()
## Roughness where the role has no ORM map.
@export_range(0.0, 1.0, 0.01) var roughness := 1.0:
	set(value):
		roughness = value
		emit_changed()
## Above this slope the role takes the ground whatever the map says (rock on the cliffs). 90 = never.
@export_range(0.0, 90.0, 0.5, "suffix:deg") var takes_slope_deg := 90.0:
	set(value):
		takes_slope_deg = value
		emit_changed()
## Projects the maps from three sides so a cliff does not stretch (presets with triplanar on).
@export var triplanar := false:
	set(value):
		triplanar = value
		emit_changed()
## Breaks the repetition of a one-picture albedo with two offset taps (presets with stochastic on).
@export var stochastic := false:
	set(value):
		stochastic = value
		emit_changed()
