@tool
class_name GameModeCatalog
extends Resource

## RFC-049 049b (F291): the modes of the game (data/modes/mode_catalog.tres) and the one this process plays. The active mode is
## `--mode=<tag>` on the command line, or 1v1. Same pattern as MapCatalog: only the tag is kept in the static (a static that holds
## a Resource of its own script is never freed). Only SacrificeFlow._apply_match_choice calls `use()` in the product.

const PATH := "res://data/modes/mode_catalog.tres"
const DEFAULT_TAG := &"1v1"

@export var modes: Array[GameMode] = []

static var _active_tag: StringName = &""


static func shared() -> GameModeCatalog:
	var catalog := load(PATH) as GameModeCatalog
	if catalog == null:
		push_error("GameModeCatalog: %s does not load." % PATH)
		catalog = GameModeCatalog.new()
	return catalog


## The tag of the mode this process plays: `--mode=<tag>`, else the default. Not read in the editor.
static func current_tag() -> StringName:
	if _active_tag == &"":
		_active_tag = DEFAULT_TAG
		if not Engine.is_editor_hint():
			for argument in OS.get_cmdline_user_args() + OS.get_cmdline_args():
				if argument.begins_with("--mode="):
					_active_tag = StringName(argument.substr(7))
					break
	return _active_tag


## The mode this process plays. An unknown tag is an error and the default plays.
static func active() -> GameMode:
	current_tag()
	var catalog := shared()
	var mode := catalog.find(_active_tag)
	if mode == null:
		push_error("GameModeCatalog: no mode '%s' in %s; playing '%s'." % [_active_tag, PATH, DEFAULT_TAG])
		_active_tag = DEFAULT_TAG
		mode = catalog.find(DEFAULT_TAG)
	return mode


## The seats of the active mode. SacrificeFlow (an autoload) asks this and not `active()`, so it never names the type GameMode: a
## script of an autoload that holds that type is left unfreed by the import.
static func active_seats() -> int:
	var mode := active()
	return mode.seats() if mode != null else 2


## Plays the mode with that tag from now on.
static func use(tag: StringName) -> void:
	_active_tag = tag


## Forgets the active mode; the next question reads `--mode` again.
static func reset() -> void:
	_active_tag = &""


func find(tag: StringName) -> GameMode:
	for mode in modes:
		if mode != null and mode.tag == tag:
			return mode
	return null


## RFC-049 049d (F293): the tags of the maps (of `maps`) that have a start for each seat of `mode`; `only_rooms` leaves out the test maps.
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
