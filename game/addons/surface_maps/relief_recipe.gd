@tool
class_name ReliefRecipe
extends Resource

## How a relief is guessed from a colour picture, the knobs of NormalMap-Online (cpetry): how strong the bumps are (strength,
## level), how smooth the height is first, which axes are flipped, and whether an ORM picture comes with the normal. The
## defaults are NormalMap-Online's (strength 2.5, level 7, smoothing 0, Sobel) and no ORM. Editor only: nothing saves a recipe
## per model (the PNG it makes is the source). Not: the pixel work (ReliefBaker).

## What the B channel of the ORM carries: metalness (Godot's ORM, for a material) or the height (a ground that blends by it).
enum PackB { METAL, HEIGHT }
## The 3x3 slope filter: Sobel (1 2 1) or Scharr (3 10 3, steeper and rounder).
enum Filter { SOBEL, SCHARR }

@export_group("Normal")
## How steep the bumps are: the normal is normalize(slope * 255, (1 + 2^level) / strength), as in NormalMap-Online.
@export_range(0.01, 10.0, 0.01) var strength := 2.5
## The flatness of the normal, the other side of `strength`: each step up halves the slope.
@export_range(0, 12) var level := 7
## Blur (> 0) or sharpen (< 0) the height before the slope, in texels (0 = as it is).
@export_range(-8, 16) var smoothing := 0
@export var filter := Filter.SOBEL
## Bright is low instead of high (for pictures whose cracks are painted light).
@export var invert_height := false
## Flip the red (X) / green (Y) of the normal. Off = OpenGL (green up), what Godot reads.
@export var invert_r := false
@export var invert_g := false
## High-pass radius in texels: the broad light painted into the picture is subtracted first (0 = off, the default).
@export_range(0, 64) var flatten_px := 0

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
