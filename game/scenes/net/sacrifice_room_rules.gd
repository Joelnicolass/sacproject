class_name SacrificeRoomRules
extends Node

## What a room needs to know about Sacrifice («Servidor local» and «Salas online»): is a pick valid, are the room
## options valid and how the ticket of a match is built. Nothing here opens a socket or starts a process.
## Ref: RFC-034 034e.

const LEVEL_MIN := 1
const LEVEL_MAX := 9
## Same hard range as GameplayPrefs.
const SOULS_MIN := 0
const SOULS_MAX := 200
const SEED_MAX := 0x7fffffff
const OPTION_KEYS: PackedStringArray = ["world", "mode", "level", "friendly_fire", "drop_soul", "starting_souls", "biome"]
## RFC-049 049f: version of the ticket this builds (2 = `mode` and `ai_seats`). The dedicated reads a ticket without them as a 1v1.
const TICKET_VERSION := 2
const BOT_KEYS: PackedStringArray = ["god", "difficulty"]

## RFC-049 049a: also accept the maps that exist to test the game (`room_selectable = false`). Tests only: the process
## starts with `--room-test-maps` to turn it on; production rooms offer only the selectable maps.
@export var include_test_maps := false

var _rng := RandomNumberGenerator.new()


## The worlds a room can play: the maps of scenes/map/maps/ that rooms offer (RFC-044), plus the test maps if asked.
func worlds() -> PackedStringArray:
	var catalog := MapCatalog.shared()
	return catalog.playable_tags() if include_test_maps else catalog.room_tags()


func _ready() -> void:
	_rng.randomize()
	if MpBoot.user_flag("room-test-maps"):
		include_test_maps = true


## `meta` of a seat: the wizard and the god, checked by the same function the dedicated uses.
func is_valid_pick(meta: Dictionary) -> bool:
	return MatchWire.decode_pick(meta, true) != null


## RFC-049 049f: a bot seat's `meta`: a god (empty = drawn when the match starts, else one the game has). 049h: and a `difficulty`
## (AiSeat.difficulty_ids(); empty or missing = Normal).
func is_valid_bot(meta: Dictionary) -> bool:
	for key in meta.keys():
		if not BOT_KEYS.has(str(key)):
			return false
	var god: Variant = meta.get("god", "")
	var difficulty: Variant = meta.get("difficulty", "")
	if not (difficulty is String and (String(difficulty).is_empty() or AiSeat.difficulty_ids().has(String(difficulty)))):
		return false
	return god is String and (String(god).is_empty() or MatchWire.decode_god(String(god), true) != null)


## Options of a room: only known keys, each of its type and inside the rules' range. Empty is fine. RFC-049 049f: the map and the
## mode (a missing one is the default) must fit: the map has a start for each seat of the mode.
func are_options_valid(options: Dictionary) -> bool:
	for key in options.keys():
		if not OPTION_KEYS.has(str(key)):
			return false
	var clean := clean_options(options)
	if clean.size() != options.size():
		return false
	return GameModeCatalog.map_fits_mode(StringName(str(clean.get("world", worlds()[0]))), StringName(str(clean.get("mode", ""))))


## RFC-049 049f: the seats of a room with these options: the seats of its mode (1v1 by default).
func seat_count_for(options: Dictionary) -> int:
	return GameModeCatalog.seats_of(StringName(str(clean_options(options).get("mode", ""))))


## The options that are valid (`world` and `biome` as string, `level` and `starting_souls` as int, the switches as bool).
## An invalid value is left out.
func clean_options(options: Dictionary) -> Dictionary:
	var out := {}
	var world: Variant = options.get("world")
	if world is String and worlds().has(world):
		out["world"] = world
	var mode: Variant = options.get("mode")
	if mode is String and GameModeCatalog.is_room_mode(StringName(mode)):
		out["mode"] = mode
	var level: Variant = options.get("level")
	if level is int and level >= LEVEL_MIN and level <= LEVEL_MAX:
		out["level"] = level
	for key in ["friendly_fire", "drop_soul"]:
		var flag: Variant = options.get(key)
		if flag is bool:
			out[key] = flag
	## The land of the match: a god that brings a look (absent = drawn from the seed by the server that simulates).
	var biome: Variant = options.get("biome")
	var land: GodType = MatchWire.decode_god(biome) if biome is String else null
	if land != null and land.look != null:
		out["biome"] = biome
	var souls: Variant = options.get("starting_souls")
	if souls is int and souls >= SOULS_MIN and souls <= SOULS_MAX:
		out["starting_souls"] = souls
	return out


## `seats`: [{slot, session_id, token, meta}] as the room hands them, plus bot seats `{slot, bot: true, meta}`. The slot is the
## seat index + 1, the pick is sanitized again, and the seed is drawn here: no client ever chooses it.
## RFC-049 049f (ticket v2): `seats` keeps only the rows with a token (the humans); the bots go to `ai_seats` [{slot, god, difficulty}], and
## the ticket names the `mode`.
func build_ticket(seats: Array, options: Dictionary) -> Dictionary:
	var rows: Array = []
	var ai_seats: Array = []
	for seat in seats:
		var row: Dictionary = seat
		if bool(row.get("bot", false)):
			var bot_meta: Dictionary = row.get("meta", {})
			ai_seats.append({"slot": int(row["slot"]), "god": str(bot_meta.get("god", "")), "difficulty": str(bot_meta.get("difficulty", ""))})
			continue
		rows.append({
			"slot": int(row["slot"]), "token": str(row["token"]),
			"meta": MatchWire.clean_pick(row.get("meta", {})),
		})
	var clean := clean_options(options)
	return {
		"ticket_version": TICKET_VERSION,
		"world": str(clean.get("world", worlds()[0])),
		"mode": str(clean.get("mode", GameModeCatalog.DEFAULT_TAG)),
		"options": clean,
		"seed": _rng.randi_range(1, SEED_MAX),
		"seats": rows,
		"ai_seats": ai_seats,
	}

