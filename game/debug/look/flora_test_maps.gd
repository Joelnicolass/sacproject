extends RefCounted

## What the flora cases need from the maps: the FloraLayer nodes of a map scene as a FloraDensity, copies of those nodes
## to hang under a bare FloraField, and the terrain to plant on. Data only; the cases are flora_field_cases.gd and
## flora_placement_cases.gd.

## The five maps of the original (the other two, tutorial_valley and alpine_meadow, are checked by flora_maps).
const ORIGINAL_MAPS := ["peaks", "roads", "winter_wonder", "high_noon", "peasantville"]
## Plants of each map, as the flora.res files held them before RFC-055 055d-d3 (the migration compared cell by cell).
const TOTALS := {
	"peaks": 11370, "roads": 15903, "winter_wonder": 9706, "high_noon": 717, "peasantville": 1530,
	"tutorial_valley": 30311, "alpine_meadow": 32079,
}

static var _cache := {}


## The FloraLayer nodes under the map's `Vegetation` node (a fresh instance of the scene, not in the tree).
static func layers_of(root: Node) -> Array:
	var vegetation := root.get_node_or_null("Vegetation")
	var found := []
	if vegetation:
		for child in vegetation.get_children():
			if child is FloraLayer:
				found.append(child)
	return found


static func density_of(map_tag: String) -> FloraDensity:
	if not _cache.has(map_tag):
		var map := MapCatalog.shared().find(StringName(map_tag))
		var root := map.map_scene.instantiate()
		_cache[map_tag] = FloraDensity.from_layers(layers_of(root))
		root.free()
	return _cache[map_tag]


## New FloraLayer nodes with the settings of the map's own.
static func layer_copies(map_tag: String) -> Array[FloraLayer]:
	var map := MapCatalog.shared().find(StringName(map_tag))
	var root := map.map_scene.instantiate()
	var copies: Array[FloraLayer] = []
	for layer: FloraLayer in layers_of(root):
		var copy := FloraLayer.new()
		copy.species = layer.species
		copy.density = layer.density
		copy.cell_m = layer.cell_m
		copy.max_per_cell = layer.max_per_cell
		copies.append(copy)
	root.free()
	return copies


## A TerrainMesh whose `shape` holds the map's ground index, to ask is_on_ground and height_at as the game does. Not in the
## tree: the caller frees it. Null when the map has no valid terrain.
static func land_of(map: MapDefinition) -> TerrainMesh:
	var data := map.terrain
	if data == null or not data.is_valid():
		return null
	var land := TerrainMesh.new()
	land.shape = GroundSurface.with_data(data)
	land.add_child(land.shape)
	return land
