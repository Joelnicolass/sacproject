@tool
class_name MapDefinition
extends Resource

## Everything the game needs to know about one map, in one `.tres` next to the map scene
## (scenes/map/maps/<tag>/<tag>.tres). A new map is a folder with its scene and one of these: MapCatalog finds it by
## scanning the folder, no list to edit. The references are typed (scene, navmesh, pictures; the ground is the scene's
## Terrain); the catalog loads a definition only when its map is asked for.

## Short name used on the command line (`--map=high_noon`) and in room options. The folder and the file have the same name.
@export var tag: StringName = &""
@export var display_name := ""
## The map scene (a MapRoot): terrain, buildings, creature spawns, navmesh region, starts and founts, sky and look.
@export var map_scene: PackedScene
## The baked light map of the ground. Empty = none.
@export var light: Texture2D
## The versioned navmesh of the map: the «Hornear navmesh» button of its NavRegion (or tools/bake/bake_nav.gd) writes it.
@export var nav: NavigationMesh
## Player seats the map has (one PlayerStart each). The sides of the NPCs come after them (SideRelations).
@export_range(1, 8) var player_starts := 2
## A picture of the map for the room screens. Empty = none yet.
@export var preview: Texture2D
## False for maps that exist to test the game (test_flat): rooms do not offer them.
@export var room_selectable := true
## False for a map that is only there to look at: no room or menu offers it, not even with the test maps;
## `--map=<tag>` and the debug scenes still open it.
@export var playable := true


## RFC-049 049d (F293): the map has a start for every seat of the mode (`player_starts >= seats`). A 2v2 does not fit High Noon.
func fits(mode: GameMode) -> bool:
	return mode != null and playable and player_starts >= mode.seats()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tag == &"":
		warnings.append("Asigná `tag`.")
	if map_scene == null:
		warnings.append("Asigná `map_scene`.")
	return warnings
