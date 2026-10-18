class_name SacrificeRoomRules
extends Node

## RFC-034 034e: what the room server needs to know about Sacrifice. The kit's lobby is generic; this node
## gives it the three Callables it calls: is a pick valid (`meta_validator`), are the room options valid
## (`options_validator`) and how the ticket of a match is built (`ticket_builder`). Nothing here opens a
## socket or starts a process.

## The only world a room can play for now.
const WORLDS: PackedStringArray = ["high_noon"]
const LEVEL_MIN := 1
const LEVEL_MAX := 9
## Same hard range as GameplayPrefs.
const SOULS_MIN := 0
const SOULS_MAX := 200
const SEED_MAX := 0x7fffffff
const OPTION_KEYS: PackedStringArray = ["world", "level", "friendly_fire", "drop_soul", "starting_souls"]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Installs the three Callables on the lobby server.
func bind(server: MpLobbyServer) -> void:
	server.meta_validator = is_valid_pick
	server.options_validator = are_options_valid
	server.ticket_builder = build_ticket


## `meta` of a seat: the wizard and the god, checked by the same function the dedicated uses.
func is_valid_pick(meta: Dictionary) -> bool:
	return not SacrificeFlow.sanitize_pick(meta).is_empty()


## Options of a room: only known keys, each of its type and inside the rules' range. Empty is fine.
func are_options_valid(options: Dictionary) -> bool:
	for key in options.keys():
		if not OPTION_KEYS.has(str(key)):
			return false
	return clean_options(options).size() == options.size()


## The options that are valid (`world` as string, `level` and `starting_souls` as int, the switches as bool).
## An invalid value is left out.
func clean_options(options: Dictionary) -> Dictionary:
	var out := {}
	var world: Variant = options.get("world")
	if world is String and WORLDS.has(world):
		out["world"] = world
	var level: Variant = options.get("level")
	if level is int and level >= LEVEL_MIN and level <= LEVEL_MAX:
		out["level"] = level
	for key in ["friendly_fire", "drop_soul"]:
		var flag: Variant = options.get(key)
		if flag is bool:
			out[key] = flag
	var souls: Variant = options.get("starting_souls")
	if souls is int and souls >= SOULS_MIN and souls <= SOULS_MAX:
		out["starting_souls"] = souls
	return out


## `seats`: [{slot, session_id, token, meta}] as MpLobbyRooms hands them. The slot is the seat index + 1, the
## pick is sanitized again, and the seed is drawn here: no client ever chooses it.
func build_ticket(seats: Array, options: Dictionary) -> Dictionary:
	var rows: Array = []
	for seat in seats:
		var row: Dictionary = seat
		rows.append({
			"slot": int(row["slot"]), "token": str(row["token"]),
			"meta": SacrificeFlow.sanitize_pick(row.get("meta", {})),
		})
	var clean := clean_options(options)
	return {
		"world": str(clean.get("world", WORLDS[0])),
		"options": clean,
		"seed": _rng.randi_range(1, SEED_MAX),
		"seats": rows,
	}

