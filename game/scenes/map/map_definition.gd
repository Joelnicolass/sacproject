@tool
class_name MapDefinition
extends Resource

## RFC-044 044b: everything the game needs to know about one map, in one `.tres` next to the map scene
## (scenes/map/maps/<tag>/<tag>.tres). A second map is a folder with its scene and one of these, listed in
## data/maps/map_catalog.tres: no code changes. Paths are strings on purpose: the catalog lists every map, and
## only the active one should load its scene, ground and navmesh.
##
## The bake inputs (`ntts_path`, `widgets_path`, `layout_scene_path`) are only read by tools/bake/bake_map_layout.gd;
## a map made by hand in the editor leaves them empty.

## Short name used on the command line (`--map=high_noon`) and in room options.
@export var tag: StringName = &""
@export var display_name := ""
## The map scene (a MapRoot): terrain, layout, navmesh region, starts and founts, sky and look.
@export_file("*.tscn") var map_scene_path := ""
## Who is allied or enemy of whom, and which sides a player takes (SideRelations reads it).
@export var sides: MapSides
## The ground as the original stores it (MapTerrainData). Bake tools and the editor fallback read it.
@export_file("*.res", "*.tres") var terrain_path := ""
## Tile index of the ground (256x256, tile id in R) and the baked light map. Empty = the map has none.
@export_file("*.png") var tiles_path := ""
@export_file("*.png") var light_path := ""
## The versioned navmesh of the map (tools/bake/bake_nav.gd writes it, `--map=<tag>`).
@export_file("*.res", "*.tres") var nav_path := ""
## Player seats the map has (one PlayerStart each). The sides of the NPCs come after them (SideRelations).
@export_range(1, 8) var player_starts := 2
## A picture of the map for the room screens. Empty = none yet.
@export_file("*.png", "*.jpg", "*.webp") var preview_path := ""
## False for maps that exist to test the game (test_flat): rooms do not offer them.
@export var room_selectable := true
@export_group("Bake inputs")
@export_file("*.tscn") var layout_scene_path := ""
@export_file("*.json") var ntts_path := ""
@export_file("*.json") var widgets_path := ""


## RFC-049 049d (F293): the map has a start for every seat of the mode (`player_starts >= seats`). A 2v2 does not fit High Noon.
func fits(mode: GameMode) -> bool:
	return mode != null and player_starts >= mode.seats()


func load_scene() -> PackedScene:
	if map_scene_path.is_empty() or not ResourceLoader.exists(map_scene_path):
		push_error("Map '%s': the scene '%s' does not exist." % [tag, map_scene_path])
		return null
	return load(map_scene_path) as PackedScene


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tag == &"":
		warnings.append("Asigná `tag`.")
	if map_scene_path.is_empty():
		warnings.append("Asigná `map_scene_path`.")
	return warnings
