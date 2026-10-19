@tool
class_name MapCatalog
extends Resource

## RFC-044 044b: the maps of the game (data/maps/map_catalog.tres) and the one this process plays. The active map is
## `--map=<tag>` on the command line, or High Noon. Everything that used to name High Noon's files (SideRelations,
## NavService, GroundMaterial, Terrain, the bake tools, the room rules) asks `MapCatalog.active()`.

const PATH := "res://data/maps/map_catalog.tres"
const DEFAULT_TAG := &"high_noon"

@export var maps: Array[MapDefinition] = []

## Only the tag of the active map is kept: a static that holds a Resource of its own script is never freed (the engine
## complains "resources still in use at exit"), and the catalog is cheap to load again (ResourceLoader caches it).
static var _active_tag: StringName = &""


static func shared() -> MapCatalog:
	var catalog := load(PATH) as MapCatalog
	if catalog == null:
		push_error("MapCatalog: %s does not load." % PATH)
		catalog = MapCatalog.new()
	return catalog


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
	var catalog := shared()
	var definition := catalog.find(_active_tag)
	if definition == null:
		push_error("MapCatalog: no map '%s' in %s; playing '%s'." % [_active_tag, PATH, DEFAULT_TAG])
		_active_tag = DEFAULT_TAG
		definition = catalog.find(DEFAULT_TAG)
	return definition


## Plays the map with that tag from now on (tests and tools; a match reads it once when it starts).
static func use(tag: StringName) -> void:
	_active_tag = tag


## Forgets the active map; the next question reads `--map` again.
static func reset() -> void:
	_active_tag = &""


func find(tag: StringName) -> MapDefinition:
	for definition in maps:
		if definition != null and definition.tag == tag:
			return definition
	return null


## The tags a room can offer.
func room_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for definition in maps:
		if definition != null and definition.room_selectable:
			tags.append(String(definition.tag))
	return tags
