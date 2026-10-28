@tool
class_name GrassSet
extends Resource

## The grass of one biome: its `GrassType` and the clearings every map gets by default (around
## the altar and the mana fountains). More clearings are `VegetationClear` nodes in the scene.

## Only the first type is drawn; a second type (flowers, tufts) is for a later scatter.
@export var types: Array[GrassType] = []
## Colors and material of this biome's grass over the shared shape. Empty = the type's own colors.
@export var palette: GrassPalette

@export_group("Default clearings")
## Group of the altar nodes and the radius of bare ground around each, with a soft edge.
@export_range(0.0, 60.0, 0.5, "suffix:m") var altar_clear_m := 11.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var altar_edge_m := 5.0
## Same for the mana fountains (group `manafount`).
@export_range(0.0, 40.0, 0.5, "suffix:m") var fount_clear_m := 4.5
@export_range(0.0, 20.0, 0.5, "suffix:m") var fount_edge_m := 3.0


func primary() -> GrassType:
	return types[0] if not types.is_empty() else null


## The first type as this biome draws it: with a palette, a runtime copy that has the palette's
## colors (the `.tres` of the type is never touched); without one, the type itself.
func resolved_type() -> GrassType:
	var type := primary()
	if type == null or palette == null:
		return type
	var copy := type.duplicate() as GrassType
	palette.apply_to(copy)
	return copy
