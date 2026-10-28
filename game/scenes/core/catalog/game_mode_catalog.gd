@tool
class_name GameModeCatalog
extends Resource

## The modes of the game (data/modes/mode_catalog.tres, in the order the screens list them). It only lists and finds; which mode
## this process plays is ActiveMatch's. A new mode is a `.tres` of GameMode dragged into `modes`.

const PATH := "res://data/modes/mode_catalog.tres"
const DEFAULT_TAG := &"1v1"

@export var modes: Array[GameMode] = []


static func shared() -> GameModeCatalog:
	var catalog := load(PATH) as GameModeCatalog
	if catalog == null:
		push_error("GameModeCatalog: %s does not load." % PATH)
		catalog = GameModeCatalog.new()
	return catalog


## Seats of the mode with that tag (empty = the default mode); 0 if there is no such mode. Plain ints and bools, for
## callers that must not name GameMode (autoloads, the room glue).
static func seats_of(tag: StringName) -> int:
	var mode := shared().find(DEFAULT_TAG if tag == &"" else tag)
	return mode.seats() if mode != null else 0


## Team of `slot` (1-based) in the mode with that tag (empty = default); an unknown mode or slot gives `-slot`, every one for itself.
static func team_of_slot(tag: StringName, slot: int) -> int:
	var mode := shared().find(DEFAULT_TAG if tag == &"" else tag)
	return mode.team_of(slot) if mode != null else -slot


## True when the mode with that tag exists and rooms offer it.
static func is_room_mode(tag: StringName) -> bool:
	return shared().room_tags().has(String(tag))


## True when the map has a start for each seat of the mode. Empty tags are the defaults (High Noon, 1v1); an unknown tag is false.
static func map_fits_mode(map_tag: StringName, mode_tag: StringName) -> bool:
	var definition := MapCatalog.shared().find(MapCatalog.DEFAULT_TAG if map_tag == &"" else map_tag)
	var mode := shared().find(DEFAULT_TAG if mode_tag == &"" else mode_tag)
	return definition != null and mode != null and definition.fits(mode)


func find(tag: StringName) -> GameMode:
	for mode in modes:
		if mode != null and mode.tag == tag:
			return mode
	return null


## The tags of the maps (of `maps`) that have a start for each seat of `mode`; `only_rooms` leaves out the test maps.
func map_tags_for(mode: GameMode, catalog: MapCatalog, only_rooms := false) -> PackedStringArray:
	var tags := PackedStringArray()
	for definition in catalog.maps:
		if definition != null and definition.fits(mode) and (definition.room_selectable or not only_rooms):
			tags.append(String(definition.tag))
	return tags


## The tags a room can offer.
func room_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for mode in modes:
		if mode != null and mode.room_selectable:
			tags.append(String(mode.tag))
	return tags
