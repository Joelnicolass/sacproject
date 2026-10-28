@tool
class_name TypeRef
extends RefCounted

## Finds the catalog type a tag names. MapBuilding and NpcSpawn keep a typed reference; their `tag`
## is derived from it, and this is how an old tag string (a debug scene, a tool) becomes the
## reference. Static and @tool: the editor has no autoloads. The id of a creature is its `tag` or,
## when empty, its file name (CreatureType.id()): the files carry human names, not tags.
## Types are read-only: never mutate what it returns.

const CREATURES_FOLDER := "res://data/catalog/creatures/"


static func building(tag: String) -> BuildingType:
	if tag.is_empty():
		return null
	var catalog := GameCatalog.shared()
	return catalog.building(tag) if catalog != null else null


static func creature(id: String) -> CreatureType:
	if id.is_empty():
		return null
	var catalog := GameCatalog.shared()
	return catalog.creature(id) if catalog != null else null


## Where the creature `id` lives (or would live, for a new one): its file when the catalog knows it,
## else `<id>.tres` in the creatures folder. For the tools that read and write the file
## (tools/bake/): they run before the catalog knows what they just made.
static func creature_path(id: String) -> String:
	var found := creature(id)
	return found.resource_path if found != null else "%s%s.tres" % [CREATURES_FOLDER, id]
