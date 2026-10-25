@tool
class_name MapCatalog
extends RefCounted

## The maps of the game and the one this process plays. A map is a folder scenes/map/maps/<tag>/ with its scene and a
## MapDefinition `<tag>.tres`; this class finds them by scanning the folder, so adding a map edits no list. The active map is
## `--map=<tag>` on the command line, or High Noon. Everything that used to name High Noon's files (SideRelations, NavService,
## GroundMaterial, Terrain, the bake tools, the room rules) asks `MapCatalog.active()`.
## A definition loads its scene, ground and navmesh: only the ones asked for are loaded (`find`, `active`); `maps` and the tag
## lists that need a flag of each one (`room_tags`) load them all.

const DIR := "res://scenes/map/maps"
const DEFAULT_TAG := &"high_noon"

## Only the tag of the active map is kept, and the definitions already loaded.
static var _active_tag: StringName = &""
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


## The tag of the map this process plays: `--map=<tag>` (read from the command line here, not through MpBoot: this
## class must not depend on the flow classes), else the default.
static func current_tag() -> StringName:
	if _active_tag == &"":
		_active_tag = DEFAULT_TAG
		if not Engine.is_editor_hint():
			for argument in OS.get_cmdline_user_args() + OS.get_cmdline_args():
				if argument.begins_with("--map="):
					_active_tag = StringName(argument.substr(6))
					break
	return _active_tag


## The map this process plays. An unknown tag is an error and the default plays.
static func active() -> MapDefinition:
	current_tag()
	var definition := shared().find(_active_tag)
	if definition == null:
		push_error("MapCatalog: no map '%s' in %s; playing '%s'." % [_active_tag, DIR, DEFAULT_TAG])
		_active_tag = DEFAULT_TAG
		definition = shared().find(DEFAULT_TAG)
	return definition


## Plays the map with that tag from now on (tests and tools; a match reads it once when it starts).
static func use(tag: StringName) -> void:
	_active_tag = tag


## Forgets the active map; the next question reads `--map` again.
static func reset() -> void:
	_active_tag = &""


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
