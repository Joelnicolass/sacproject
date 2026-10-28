@tool
class_name SideRelations
extends Node

## Who is the enemy of whom. The matrix is the SIDS of the map: each side has a bit mask of allies
## and one of enemies, and the stance is read from the first side towards the second; a side is its
## own ally. Slot = side + 1 (players 1 and 2, Farmers 3, Taurocks 4); slot 0 is the neutral side
## 31, the owner of the map's houses, which has no relations and which nobody has as an enemy (High
## Noon: enemies 0xe and 0x7ffffffd… skip bit 31). That is the rule for High Noon, which has two
## seats. A seat (a player slot) and a side of the map are different things: the seats are the first
## `MapDefinition.player_starts` slots and take the sides players can take (assignment != 0) in
## order; the sides no player takes (NPCs) come after the seats. With two seats this is the old slot
## = side + 1, so a map with four seats puts its NPCs in slots 5 and up instead of on the seats of
## players 3 and 4. On top of the SIDS goes the team overlay of the game mode, applied after seating
## the wizards: two seats of the mode are allies when they share a team and enemies when they do
## not; NPCs and houses keep the SIDS. The overlay is installed only when the mode has allies or
## more than two seats, so 1v1 follows the old path untouched. The map's rows come from its scene
## (MapSides.rows_of: the PlayerStart seats with their `team` and the sides its NpcSpawns name).
## Without them, or for a side the map does not describe, «another slot is an enemy» (what the port
## did before). It is the node `Context/Sides` of match.tscn: MatchWorld calls `use(map, mode)` from
## its _enter_tree, before any of its systems is ready, and the relations hold until this node
## leaves the tree. The static functions are how everybody asks (bodies, spells, the HUD; @tool code
## in the editor too): they forward to the relations of the match in the tree, and without a match
## they answer with no rows (every other slot an enemy).

enum Stance { NEUTRAL, ALLY, ENEMY }

const NEUTRAL_SIDE := 31

## The relations of the running match (set by use, cleared in _exit_tree); null = no match.
static var _live: SideRelations
## A question came with no match outside the editor: warned once per process.
static var _warned := false
## The answers with no match: no rows, two seats, no teams. Never written.
static var _no_rows := Table.new()

var _table := Table.new()


## The sides of `map` (MapSides.rows_of its scene, its seats) and the team overlay of `mode`, from
## now on: this becomes the relations everybody asks. A null map leaves no rows (every slot an
## enemy).
func use(map: MapDefinition, mode: GameMode) -> void:
	_table = Table.new()
	_table.set_rows(
		MapSides.rows_of(map.map_scene) if map != null else [],
		map.player_starts if map != null else 2
	)
	_table.install_mode(mode)
	_live = self


func _exit_tree() -> void:
	if _live == self:
		_live = null


## True when the team overlay of a mode with allies or more than two seats is on.
static func has_teams() -> bool:
	return not _rows().team_of_seat.is_empty()


## The team of a slot: the mode's for a seat of the mode, else `-slot` (its own team: NPCs, the
## neutral side, or no overlay). With `-slot` for everybody (1v1) the team rules give back the old
## «every slot for itself».
static func team_of(slot: int) -> int:
	return _rows().team_of(slot)


static func side_of(slot: int) -> int:
	return _rows().side_of(slot)


static func slot_of(side: int) -> int:
	return _rows().slot_of(side)


## The player seats of the map being played (MapDefinition.player_starts).
static func seat_count() -> int:
	return _rows().seat_count


## True when the map describes both sides (otherwise the old rule applies).
static func knows(slot_a: int, slot_b: int) -> bool:
	return _rows().knows(slot_a, slot_b)


static func stance(from_slot: int, to_slot: int) -> Stance:
	if from_slot == to_slot:
		return Stance.ALLY
	return _rows().stance(from_slot, to_slot)


## The seats that are allies of `slot` (not itself): who shares its sight
## (MatchRules.allied_vision). Empty in a 1v1.
static func allies_of(slot: int) -> Array[int]:
	var rows := _rows()
	var found: Array[int] = []
	for other in range(1, rows.seat_count + 1):
		if other != slot and rows.stance(slot, other) == Stance.ALLY:
			found.append(other)
	return found


static func is_enemy(from_slot: int, to_slot: int) -> bool:
	return stance(from_slot, to_slot) == Stance.ENEMY


## A side of the map no player takes (assignment 0 and not the neutral side): Farmers and Taurocks.
static func is_npc_slot(slot: int) -> bool:
	var rows := _rows()
	var side := rows.side_of(slot)
	return slot > 0 and rows.assignment.has(side) and int(rows.assignment[side]) == 0


## The table of the running match; with none, the empty one (and one warning outside the editor).
static func _rows() -> Table:
	if _live != null:
		return _live._table
	if not _warned and not Engine.is_editor_hint():
		_warned = true
		push_warning(
			"SideRelations: asked with no match in the tree; every other slot is an enemy."
		)
	return _no_rows


## The rows of one map and the team overlay of one mode: the data of the relations and the questions
## on it.
class Table:
	extends RefCounted

	var allies: Dictionary = {}
	var enemies: Dictionary = {}
	var assignment: Dictionary = {}
	## Side ids a player can take (assignment != 0), in order: seat k is `seat_sides[k - 1]`.
	var seat_sides: Array[int] = []
	## Side ids no player takes and that are not the neutral one, in order: NPC k is the slot `seats
	## + k + 1`.
	var npc_sides: Array[int] = []
	## MapDefinition.player_starts of the map the rows were read for (the hot paths ask it all the
	## time).
	var seat_count := 2
	## Team overlay: the team of each seat (seat 1 first). Empty = not installed.
	var team_of_seat: PackedInt32Array = PackedInt32Array()

	## `rows`: [{id, allies, enemies, assignment}] as MapSides.rows_of gives them; `seats` = how
	## many are players.
	func set_rows(rows: Array, seats: int) -> void:
		for row: Variant in rows:
			if not row is Dictionary:
				continue
			var id := int(row.get("id", -1))
			allies[id] = int(row.get("allies", 0))
			enemies[id] = int(row.get("enemies", 0))
			assignment[id] = int(row.get("assignment", 0))
			if id == NEUTRAL_SIDE:
				continue
			if assignment[id] != 0:
				seat_sides.append(id)
			else:
				npc_sides.append(id)
		# The seat is the side whose `assignment & 31` is i + 1, not the n-th by id.
		seat_sides.sort_custom(_before_by_seat)
		npc_sides.sort()
		seat_count = seats

	func _before_by_seat(a: int, b: int) -> bool:
		var seat_a := int(assignment[a]) & 31
		var seat_b := int(assignment[b]) & 31
		return seat_a < seat_b if seat_a != seat_b else a < b

	## Installs the team overlay of `mode` (nothing for null or a 1v1).
	func install_mode(mode: GameMode) -> void:
		team_of_seat = PackedInt32Array()
		if mode != null and (mode.has_allies() or mode.seats() > 2):
			team_of_seat = mode.team_of_seat.duplicate()

	## The seat of the mode this slot occupies (the slots 1..min(mode seats, map seats)), or false.
	func in_mode(slot: int) -> bool:
		return slot >= 1 and slot <= team_of_seat.size() and slot <= seat_count

	func team_of(slot: int) -> int:
		return team_of_seat[slot - 1] if in_mode(slot) else -slot

	func side_of(slot: int) -> int:
		if slot <= 0:
			return NEUTRAL_SIDE
		if slot <= seat_count:
			return seat_sides[slot - 1] if slot - 1 < seat_sides.size() else slot - 1
		var npc := slot - seat_count - 1
		return npc_sides[npc] if npc < npc_sides.size() else slot - 1

	func slot_of(side: int) -> int:
		if side == NEUTRAL_SIDE:
			return 0
		var seat := seat_sides.find(side)
		if seat >= 0 and seat < seat_count:
			return seat + 1
		var npc := npc_sides.find(side)
		if npc >= 0:
			return seat_count + npc + 1
		return side + 1

	func knows(slot_a: int, slot_b: int) -> bool:
		return enemies.has(side_of(slot_a)) and enemies.has(side_of(slot_b))

	func stance(from_slot: int, to_slot: int) -> Stance:
		if from_slot == to_slot:
			return Stance.ALLY
		if in_mode(from_slot) and in_mode(to_slot):
			return (
				Stance.ALLY
				if team_of_seat[from_slot - 1] == team_of_seat[to_slot - 1]
				else Stance.ENEMY
			)
		if not knows(from_slot, to_slot):
			return Stance.ENEMY
		var from_side := side_of(from_slot)
		var bit := 1 << side_of(to_slot)
		if int(allies.get(from_side, 0)) & bit:
			return Stance.ALLY
		if int(enemies.get(from_side, 0)) & bit:
			return Stance.ENEMY
		return Stance.NEUTRAL
