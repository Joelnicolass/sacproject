@tool
class_name ActiveMatch
extends RefCounted

## The map, the mode and the seed this process plays. The one place that knows which they are: the flow chooses them when a match
## starts, a client takes the ones the server announces, and the world, the sides and the screens only read them.
## With nothing chosen it plays what `--map=<tag>` / `--mode=<tag>` say, else High Noon in 1v1.
## It does not decide what a screen offers (the catalogs list that) and it does not travel on the wire (MatchWire does).

## The ids of the choice, as the catalogs know them; empty = not read yet. The id is kept (not the Resource) so the editor
## always sees the file as it is on disk and no static holds a Resource.
static var _map_id: StringName = &""
static var _mode_id: StringName = &""
## The seed of the match the server announced (or chose); 0 = none (the world draws its own, offline).
static var _seed := 0


## The map this process plays. An unknown `--map` is an error and the default plays.
static func map() -> MapDefinition:
	if _map_id == &"":
		_map_id = _flag("map", MapCatalog.DEFAULT_TAG)
	var found := MapCatalog.shared().find(_map_id)
	if found == null:
		push_error("ActiveMatch: no map '%s' in %s; playing '%s'." % [_map_id, MapCatalog.DIR, MapCatalog.DEFAULT_TAG])
		_map_id = MapCatalog.DEFAULT_TAG
		found = MapCatalog.shared().find(_map_id)
	return found


## The mode this process plays. An unknown `--mode` is an error and the default plays.
static func mode() -> GameMode:
	if _mode_id == &"":
		_mode_id = _flag("mode", GameModeCatalog.DEFAULT_TAG)
	var found := GameModeCatalog.shared().find(_mode_id)
	if found == null:
		push_error("ActiveMatch: no mode '%s' in %s; playing '%s'." % [_mode_id, GameModeCatalog.PATH, GameModeCatalog.DEFAULT_TAG])
		_mode_id = GameModeCatalog.DEFAULT_TAG
		found = GameModeCatalog.shared().find(_mode_id)
	return found


## The tag of the map this process plays, without loading its definition (the wire and the logs only need the tag).
static func map_tag() -> StringName:
	if _map_id == &"":
		_map_id = _flag("map", MapCatalog.DEFAULT_TAG)
	return _map_id


## The tag of the mode this process plays, without loading the catalog. SideRelations asks it on every side query (thousands of
## times a frame): it must cost a variable read.
static func mode_tag() -> StringName:
	if _mode_id == &"":
		_mode_id = _flag("mode", GameModeCatalog.DEFAULT_TAG)
	return _mode_id


## A client plays the map and the mode the server announced, by tag: the server already checked that they fit, and the map's
## definition (its scene, ground and navmesh) loads only when the world needs it, not while the client is being admitted.
static func choose_ids(map_id: StringName, mode_id: StringName) -> void:
	_map_id = map_id
	_mode_id = mode_id


## The seed of this match on every peer: the one the server chose (SacrificeFlow) or announced (MatchWire); 0 = none.
static func match_seed() -> int:
	return _seed


## Plays this seed (the server chose it, or it came in the snapshot). 0 forgets it.
static func choose_seed(value: int) -> void:
	_seed = maxi(value, 0)


## How many seats the match has (those of the mode).
static func seats() -> int:
	var found := mode()
	return found.seats() if found != null else 2


## Plays `map_choice` in `mode_choice` from now on. A null one is forgotten (the flag or the default plays). A mode needs a start
## for each of its seats: if the map has fewer, the default mode plays. Calling it twice with the same arguments changes nothing.
static func choose(map_choice: MapDefinition, mode_choice: GameMode) -> void:
	_map_id = map_choice.tag if map_choice != null else &""
	_mode_id = mode_choice.tag if mode_choice != null else &""
	var chosen_map := map()
	var chosen_mode := mode()
	if chosen_map == null or chosen_mode == null:
		return
	if not chosen_map.fits(chosen_mode):
		push_error("ActiveMatch: el modo '%s' pide %d asientos y el mapa '%s' tiene %d; se juega '%s'." % [
			chosen_mode.tag, chosen_mode.seats(), chosen_map.tag, chosen_map.player_starts, GameModeCatalog.DEFAULT_TAG])
		_mode_id = GameModeCatalog.DEFAULT_TAG


## Forgets the choice; the next question reads the flags again.
static func forget() -> void:
	_map_id = &""
	_mode_id = &""
	_seed = 0


## The files the loading screen loads on a thread before the world: the definition of the map (it brings its scene, ground and navmesh)
## and, on a peer that draws, the looks of every body an offered god or wizard can field (the warm-up draws them all; WarmCollect
## finds them in the catalog, which is already loaded). Reads only the map's tag: no file is loaded here.
static func load_paths() -> PackedStringArray:
	var paths := PackedStringArray([MapCatalog.path_of(map_tag())])
	if BodyLook.loads_meshes() and not Engine.is_editor_hint():
		var catalog := GameCatalog.shared()
		paths.append_array(WarmCollect.look_paths([catalog.offered_gods(), catalog.offered_wizards()]))
	return paths



## `--<name>=<tag>` of the command line (not read in the editor), else `fallback`.
static func _flag(flag_name: String, fallback: StringName) -> StringName:
	if not Engine.is_editor_hint():
		var prefix := "--%s=" % flag_name
		for argument in OS.get_cmdline_user_args() + OS.get_cmdline_args():
			if argument.begins_with(prefix):
				return StringName(argument.substr(prefix.length()))
	return fallback
