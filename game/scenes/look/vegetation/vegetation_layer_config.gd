@tool
class_name VegetationLayerConfig
extends Resource

## RFC-054 054c (F382): one mesh vegetation layer of FloraField (data/look/vegetation/<id>.tres): where its density comes
## from, which species it draws and how far. A MeshPlanter draws it. A fourth layer is another .tres, not more code.
## A type template: never mutated at runtime.

enum DensitySource {
	## The layer draws nothing (trees.tres: the trees of the original are MapBuilding, RFC-054 §4.6).
	NONE,
	## Every tag of the map's FloraMap draws the prop with its own name (or its species entry / substitute).
	MAP_TAGS,
	## One tag of the FloraMap (`map_tag`), its plants split among `species` by weight.
	MAP_TAG,
	## Baked positions (054g, not built yet): draws nothing for now.
	BAKED,
}

## Matches `VegetationQuality.layer_id` in the presets.
@export var id: StringName = &"original_plants"
@export var density_source: DensitySource = DensitySource.MAP_TAGS
## MAP_TAG only.
@export var map_tag := ""
## MAP_TAGS: per-tag entries (the rest use `default_species`). MAP_TAG: the species the tag splits into.
@export var species: Array[VegetationSpecies] = []
## MAP_TAGS: the look of a tag without an entry in `species` (its model is the tag itself).
@export var default_species: VegetationSpecies
## Density tag -> model, for a tag whose own prop is missing (RFC-054 §12).
@export var model_substitutes: Dictionary = {}
## Radius of the ring of cells around the camera at radius_scale 1 (camera distance: a high camera sees less of it).
@export_range(10.0, 400.0, 1.0, "suffix:m") var radius_m := 160.0
## Plants dither out over this many meters before their end (the radius or the species' visibility_end_m).
@export_range(0.0, 60.0, 0.5, "suffix:m") var fade_m := 12.0
## Level of detail: from tier_starts_m[i] (ground distance to the camera, scaled with the radius) a cell draws the first
## tier_fractions[i] of its instances (`visible_instance_count`: FloraPlacement makes any prefix an even sample).
@export var tier_starts_m := PackedFloat32Array([0.0, 60.0, 110.0])
@export var tier_fractions := PackedFloat32Array([1.0, 0.75, 0.5])
## FloraPlacement seed: another seed scatters the same counts elsewhere in each cell.
@export var placement_seed := 54


## The species entry that draws density tag `tag` (MAP_TAGS), or `default_species`, or null.
func species_for_tag(tag: String) -> VegetationSpecies:
	for entry in species:
		if entry and entry.density_tag() == tag:
			return entry
	return default_species


## The prop a density tag draws with `entry`: a substitute wins.
func model_for(tag: String, entry: VegetationSpecies) -> String:
	if model_substitutes.has(tag):
		return str(model_substitutes[tag])
	return entry.model_for(tag) if entry else tag


func draws() -> bool:
	return density_source == DensitySource.MAP_TAGS or density_source == DensitySource.MAP_TAG
