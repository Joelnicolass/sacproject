@tool
class_name VegetationLayerConfig
extends Resource

## One mesh vegetation layer of FloraField (data/look/vegetation/<id>.tres): how far it draws, how
## it fades and how its levels of detail go. WHAT it draws is not here: the FloraLayer nodes of the
## map (and the VegetationPatch nodes) say where each species grows. A MeshPlanter draws it. A type
## template: never mutated at runtime.

## Matches `VegetationQuality.layer_id` in the presets.
@export var id: StringName = &"original_plants"
## Radius of the ring of cells around the camera at radius_scale 1 (camera distance: a high camera
## sees less of it).
@export_range(10.0, 400.0, 1.0, "suffix:m") var radius_m := 160.0
## Plants dither out over this many meters before their end (the radius or the species'
## visibility_end_m).
@export_range(0.0, 60.0, 0.5, "suffix:m") var fade_m := 12.0
## Level of detail: from tier_starts_m[i] (ground distance to the camera, scaled with the radius) a
## cell draws the first tier_fractions[i] of its instances (`visible_instance_count`: FloraPlacement
## makes any prefix an even sample).
@export var tier_starts_m := PackedFloat32Array([0.0, 60.0, 110.0])
@export var tier_fractions := PackedFloat32Array([1.0, 0.75, 0.5])
## FloraPlacement seed: another seed scatters the same counts elsewhere in each cell.
@export var placement_seed := 54
