@tool
class_name MapCatalog
extends RefCounted

## The maps of the game, found by scanning the folder scenes/map/maps/<tag>/ (its scene and a MapDefinition `<tag>.tres`):
## adding a map edits no list. It only lists and finds; which map this process plays is ActiveMatch's.
## A definition loads its scene, ground and navmesh: only the ones asked for are loaded (`find`); `maps` and the tag lists that
## need a flag of each one (`room_tags`) load them all.

const DIR := "res://scenes/map/maps"
const DEFAULT_TAG := &"high_noon"

## The definitions already loaded.
static var _loaded: Dictionary = {}

## Every map, the default first, the test maps last. Loads them all.
var maps: Array[MapDefinition]:
	get:
		var found: Array[MapDefinition] = []
		for tag in all_tags():
			var definition := find(StringName(tag))
			if definition != null:
				found.append(definition)
		return found


static func shared() -> MapCatalog:
	return MapCatalog.new()


## The map this process plays (a bridge to ActiveMatch for the readers of the world).
static func active() -> MapDefinition:
	return ActiveMatch.map()


## The tag of the map this process plays.
static func current_tag() -> StringName:
	return ActiveMatch.map_tag()


## True when the folder has a definition with that tag. Loads nothing (a definition brings its scene, ground and navmesh: seconds).
func has(tag: StringName) -> bool:
	return ResourceLoader.exists("%s/%s/%s.tres" % [DIR, tag, tag])


## The definition with that tag, loaded once. Null when the folder has none.
func find(tag: StringName) -> MapDefinition:
	if not _loaded.has(tag) or Engine.is_editor_hint():
		var path := "%s/%s/%s.tres" % [DIR, tag, tag]
		_loaded[tag] = load(path) as MapDefinition if ResourceLoader.exists(path) else null
	return _loaded[tag]


## The tags a room can offer.
func room_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for definition in maps:
		if definition.room_selectable and definition.playable:
			tags.append(String(definition.tag))
	return tags


## The maps a screen offers with the test maps on: all of them but the ones only there to look at (`playable` off).
func playable_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for tag in all_tags():
		var definition := find(StringName(tag))
		if definition != null and definition.playable:
			tags.append(tag)
	return tags


## RFC-049 049a: every tag, the test maps included (a room server started with `--room-test-maps`, the debug boot).
func all_tags() -> PackedStringArray:
	var tags := Array(DirAccess.get_directories_at(DIR))
	tags = tags.filter(func(tag: String) -> bool: return ResourceLoader.exists("%s/%s/%s.tres" % [DIR, tag, tag]))
	tags.sort_custom(func(a: String, b: String) -> bool:
		var ka := [a != String(DEFAULT_TAG), a.begins_with("test"), a]
		var kb := [b != String(DEFAULT_TAG), b.begins_with("test"), b]
		return ka < kb)
	return PackedStringArray(tags)
