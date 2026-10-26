@tool
class_name ReliefRecipe
extends Resource

## How a relief is guessed from a colour picture: how strong the bumps are, how much of the painted light is taken away
## first, how smooth the result is and whether an ORM picture comes with the normal. The defaults are a soft relief and no
## ORM. Editor only: nothing saves a recipe per model (the PNG it makes is the source). Not: the pixel work (ReliefBaker).

## What the B channel of the ORM carries: metalness (Godot's ORM, for a material) or the height (a ground that blends by it).
enum PackB { METAL, HEIGHT }

@export_group("Normal")
## How steep the bumps are. 1 = a brightness step of 1/16 between two texels tilts the normal 45°.
@export_range(0.0, 4.0, 0.01) var strength := 0.3
## Smoothing of the height before the normal, in texels (0 = none). Hides the noise of a painted picture.
@export_range(0, 16) var blur_px := 1
## High-pass radius in texels: the broad light painted into the picture is subtracted (0 = keep it).
@export_range(0, 64) var flatten_px := 12
## Bright is low instead of high (for pictures whose cracks are painted light).
@export var invert := false

@export_group("ORM")
## Also make the ORM picture (R occlusion, G roughness, B per `pack_b`). Off by default: a varying roughness reads as plastic.
@export var orm := false
## How dark the hollows get in R (0 = no occlusion).
@export_range(0.0, 4.0, 0.01) var ao_strength := 0.5
## Radius in texels of what counts as a hollow around a texel.
@export_range(1, 32) var ao_radius_px := 4
## G for every texel (the material's own roughness).
@export_range(0.0, 1.0, 0.01) var roughness := 0.85
## How much darker texels get rougher than `roughness` (0 = constant roughness).
@export_range(0.0, 1.0, 0.01) var roughness_from_luma := 0.0
## B when `pack_b` is METAL.
@export_range(0.0, 1.0, 0.01) var metallic := 0.0
@export var pack_b := PackB.METAL

@export_group("Layout")
## 0 = one picture with clamped edges. N = an N x N sheet of tiles: each tile wraps on itself (a tiled ground's variants).
@export_range(0, 8) var tile_cells := 0
## Texels below this alpha are holes of a cutout: they take the height of the nearest solid texel, so the edge leaves no halo.
@export_range(0.0, 1.0, 0.01) var alpha_cut := 0.5
