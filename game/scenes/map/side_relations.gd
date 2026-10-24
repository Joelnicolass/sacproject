@tool
class_name SideRelations
extends RefCounted

## Who is the enemy of whom (RFC-024 addendum 1, 024b2). The matrix is the SIDS of the map
## (sids.d, state.d Sides.getStance): each side has a bit mask of allies and one of enemies, and the
## stance is read from the first side towards the second; a side is its own ally. Slot = side + 1
## (players 1 and 2, Farmers 3, Taurocks 4); slot 0 is the neutral side 31, the owner of the map's houses,
## which has no relations and which nobody has as an enemy (High Noon: enemies 0xe and 0x7ffffffd… skip bit 31).
## RFC-044 044c: that is the rule for High Noon, which has two seats. A seat (a player slot) and a side of the map are
## different things: the seats are the first `MapDefinition.player_starts` slots and take the sides players can take
## (assignment != 0) in order; the sides no player takes (NPCs) come after the seats. With two seats this is the old
## slot = side + 1, so a map with four seats puts its NPCs in slots 5 and up instead of on the seats of players 3 and 4.
## RFC-049 049b (F291): on top of the SIDS goes the team overlay of the game mode, as sacengine stanceSettings does after seating the
## wizards: two seats of the mode are allies when they share a team and enemies when they do not; NPCs and houses keep the SIDS.
## The overlay is installed only when the mode has allies or more than two seats, so 1v1 follows the old path untouched.
## The map's rows come from its scene (MapSides.rows_of: the PlayerStart seats with their `team` and the sides its NpcSpawns
## name). Without them, or for a side the map does not describe, «another slot is an enemy» (what the port did before). Static and @tool: the editor and a headless run read it
## without autoloads, and the suite can load its own rows with set_rows().

enum Stance { NEUTRAL, ALLY, ENEMY }

const NEUTRAL_SIDE := 31

static var _loaded := false
static var _allies: Dictionary = {}
static var _enemies: Dictionary = {}
static var _assignment: Dictionary = {}
## The tag of the map the rows come from; empty when they were set by hand (set_rows).
static var _rows_tag: StringName = &""
## Side ids a player can take (assignment != 0), in order: seat k is `_seat_sides[k - 1]`.
static var _seat_sides: Array[int] = []
## Side ids no player takes and that are not the neutral one, in order: NPC k is the slot `seats + k + 1`.
static var _npc_sides: Array[int] = []
## MapDefinition.player_starts of the map the rows were read for (the hot paths ask it all the time).
static var _seat_count := 2
## Team overlay (RFC-049 049b): the mode it was read for, and the team of each seat (seat 1 first). Empty = not installed.
static var _mode_tag: StringName = &""
static var _team_of_seat: PackedInt32Array = PackedInt32Array()


## Forgets what was read; the next question reads the sides of the active map (MapSides.rows_of its scene) again.
static func refresh() -> void:
	var map := MapCatalog.active()
	_seat_count = map.player_starts
	set_rows(MapSides.rows_of(map.map_scene))
	_rows_tag = map.tag
	_install_mode()


## `rows`: [{id, allies, enemies, assignment}] as MapSides.rows_of gives them. `seats` >= 0 also sets the seat count (a suite
## that writes its own rows says how many are players); -1 keeps the one of the last map.
static func set_rows(rows: Array, seats := -1) -> void:
	_loaded = true
	_rows_tag = &""
	_allies = {}
	_enemies = {}
	_assignment = {}
	_seat_sides = []
	_npc_sides = []
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var id := int(row.get("id", -1))
		_allies[id] = int(row.get("allies", 0))
		_enemies[id] = int(row.get("enemies", 0))
		_assignment[id] = int(row.get("assignment", 0))
		if id == NEUTRAL_SIDE:
			continue
		if _assignment[id] != 0:
			_seat_sides.append(id)
		else:
			_npc_sides.append(id)
	## sacengine multiplayerSide(i): the seat is the side whose `assignment & 31` is i + 1, not the n-th by id.
	_seat_sides.sort_custom(_before_by_seat)
	_npc_sides.sort()
	if seats >= 0:
		_seat_count = seats
	_install_mode()


static func _before_by_seat(a: int, b: int) -> bool:
	var seat_a := int(_assignment[a]) & 31
	var seat_b := int(_assignment[b]) & 31
	return seat_a < seat_b if seat_a != seat_b else a < b


## Reads the active mode and installs (or clears) the team overlay.
static func _install_mode() -> void:
	_mode_tag = GameModeCatalog.current_tag()
	_team_of_seat = PackedInt32Array()
	var mode := GameModeCatalog.active()
	if mode != null and (mode.has_allies() or mode.seats() > 2):
		_team_of_seat = mode.team_of_seat.duplicate()


## True when the team overlay of a mode with allies or more than two seats is on.
static func has_teams() -> bool:
	_ensure()
	return not _team_of_seat.is_empty()


## The seat of the mode this slot occupies (the slots 1..min(mode seats, map seats)), or false.
static func _in_mode(slot: int) -> bool:
	return slot >= 1 and slot <= _team_of_seat.size() and slot <= _seat_count


## The team of a slot: the mode's for a seat of the mode, else `-slot` (its own team: NPCs, the neutral side, or no overlay).
## With `-slot` for everybody (1v1) the team rules give back the old «every slot for itself».
static func team_of(slot: int) -> int:
	_ensure()
	return _team_of_seat[slot - 1] if _in_mode(slot) else -slot


static func side_of(slot: int) -> int:
	if slot <= 0:
		return NEUTRAL_SIDE
	_ensure()
	var seats := seat_count()
	if slot <= seats:
		return _seat_sides[slot - 1] if slot - 1 < _seat_sides.size() else slot - 1
	var npc := slot - seats - 1
	return _npc_sides[npc] if npc < _npc_sides.size() else slot - 1


static func slot_of(side: int) -> int:
	if side == NEUTRAL_SIDE:
		return 0
	_ensure()
	var seat := _seat_sides.find(side)
	if seat >= 0 and seat < seat_count():
		return seat + 1
	var npc := _npc_sides.find(side)
	if npc >= 0:
		return seat_count() + npc + 1
	return side + 1


## The player seats of the map being played (MapDefinition.player_starts).
static func seat_count() -> int:
	_ensure()
	return _seat_count


## True when the map describes both sides (otherwise the old rule applies).
static func knows(slot_a: int, slot_b: int) -> bool:
	_ensure()
	return _enemies.has(side_of(slot_a)) and _enemies.has(side_of(slot_b))


static func stance(from_slot: int, to_slot: int) -> Stance:
	if from_slot == to_slot:
		return Stance.ALLY
	_ensure()
	if _in_mode(from_slot) and _in_mode(to_slot):
		return Stance.ALLY if _team_of_seat[from_slot - 1] == _team_of_seat[to_slot - 1] else Stance.ENEMY
	if not knows(from_slot, to_slot):
		return Stance.ENEMY
	var from_side := side_of(from_slot)
	var bit := 1 << side_of(to_slot)
	if int(_allies.get(from_side, 0)) & bit:
		return Stance.ALLY
	if int(_enemies.get(from_side, 0)) & bit:
		return Stance.ENEMY
	return Stance.NEUTRAL


## The seats that are allies of `slot` (not itself): who shares its sight (MatchRules.allied_vision). Empty in a 1v1.
static func allies_of(slot: int) -> Array[int]:
	var found: Array[int] = []
	_ensure()
	for other in range(1, _seat_count + 1):
		if other != slot and stance(slot, other) == Stance.ALLY:
			found.append(other)
	return found


static func is_enemy(from_slot: int, to_slot: int) -> bool:
	return stance(from_slot, to_slot) == Stance.ENEMY


## A side of the map no player takes (assignment 0 and not the neutral side): Farmers and Taurocks.
static func is_npc_slot(slot: int) -> bool:
	_ensure()
	var side := side_of(slot)
	return slot > 0 and _assignment.has(side) and int(_assignment[side]) == 0


static func _ensure() -> void:
	# The rows of the map are read again when the active map changes (MapCatalog.use); rows set by hand stay.
	if not _loaded or (_rows_tag != &"" and _rows_tag != MapCatalog.current_tag()):
		refresh()
	elif _mode_tag != GameModeCatalog.current_tag():
		_install_mode()
