@tool
class_name TypeRef
extends RefCounted

## Finds the catalog type a tag names (RFC-043 043b). MapBuilding and NpcSpawn keep a typed reference; their `tag` is derived from it,
## and this is how an old tag string (a debug scene, a tool) becomes the reference. Static and @tool: the editor has no autoloads.
## First the type's own file (data/catalog/<kind>/<tag>.tres, one source of truth), then the list of the saved GameCatalog, so it
## works whichever of the two the catalog is loaded from. Types are read-only: never mutate what it returns.

const BUILDINGS_FOLDER := "res://data/catalog/buildings/"
const CREATURES_FOLDER := "res://data/catalog/creatures/"


static func building(tag: String) -> BuildingType:
	if tag.is_empty():
		return null
	var found := _from_file(BUILDINGS_FOLDER, tag) as BuildingType
	if found != null:
		return found
	var catalog := GameCatalog.shared()
	if catalog != null:
		for candidate in catalog.buildings:
			if candidate.tag == tag:
				return candidate
	return null


static func creature(tag: String) -> CreatureType:
	if tag.is_empty():
		return null
	var found := _from_file(CREATURES_FOLDER, tag) as CreatureType
	if found != null:
		return found
	var catalog := GameCatalog.shared()
	if catalog != null:
		for candidate in catalog.creatures:
			if candidate.tag == tag:
				return candidate
	return null


static func _from_file(folder: String, tag: String) -> Resource:
	var path := "%s%s.tres" % [folder, tag]
	if ResourceLoader.exists(path):
		return load(path)
	return null
