@tool
class_name GroundSet
extends Resource

## The ground of one biome: up to four `GroundLayer` and the zones they follow. Order matters:
## the low preset uses only the first layers (grass and rock first). Several biomes can share
## layers. The set is data only; `TerrainLayer` shows it.

const MAX_LAYERS := 4

@export var layers: Array[GroundLayer] = []
## Original map zones -> layer slot.
@export var tiles: TileLayerMap

@export_group("Blend")
## Width of the blend between layers. Smaller = sharper, more visible height contrast.
@export_range(0.02, 0.6, 0.01) var blend_depth := 0.18
## Sharpens the original zone edges after they are broken with noise (the zones are 10 m cells).
@export_range(0.0, 1.0, 0.01) var zone_edge_noise := 0.55

## Width of the soft edge of the patches (patchiness noise range). 0.1 = stamped, 0.5 = gradual.
@export_range(0.05, 0.6, 0.01) var patch_softness := 0.32

@export_group("Variation (anti-repetition)")
@export_range(20.0, 600.0, 1.0, "suffix:m") var macro_scale_m := 200.0
## Brightness and color drift of the ground at the macro scale.
@export_range(0.0, 0.8, 0.01) var macro_strength := 0.28
## Roughness drift at the macro scale.
@export_range(0.0, 0.6, 0.01) var macro_roughness := 0.15
@export_range(2.0, 80.0, 0.5, "suffix:m") var patch_scale_m := 26.0

@export_group("Relief")
## Rolling bumps of the ground that the 10 m mesh does not have, made as a normal from noise
## (no geometry, heights and collision stay the same). 0 = off.
@export_range(0.0, 3.0, 0.05, "suffix:m") var bump_height_m := 0.6
## Wavelength of the biggest bumps (the second set is a quarter of it).
@export_range(4.0, 80.0, 0.5, "suffix:m") var bump_scale_m := 36.0

@export_group("Original light map")
## The map's baked light as a faint tint (its shadows clash with the new sun, so 0 = off).
@export_range(0.0, 0.25, 0.01) var lightmap_tint := 0.0
