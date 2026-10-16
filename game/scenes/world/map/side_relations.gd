@tool
class_name SideRelations
extends RefCounted

## Who is the enemy of whom (RFC-024 addendum 1, 024b2). The matrix is the SIDS of the map
## (sids.d, state.d Sides.getStance): each side has a bit mask of allies and one of enemies, and the
## stance is read from the first side towards the second; a side is its own ally. Slot = side + 1
## (players 1 and 2, Farmers 3, Taurocks 4); slot 0 is the neutral side 31, the owner of the map's houses,
## which has no relations and which nobody has as an enemy (High Noon: enemies 0xe and 0x7ffffffd… skip bit 31).
## The map's rows live in `cache/high_noon_ntts.json` (tools/export_high_noon_ntts.py); nothing of the original
## is stored in the repo. Without the file, or for a side the file does not describe, «another slot is an
## enemy» (what the port did before this cut). Static and @tool: the editor and a headless run read it
## without autoloads, and the suite can load its own rows with set_rows().

enum Stance { NEUTRAL, ALLY, ENEMY }

const NTTS_PATH := "res://cache/high_noon_ntts.json"
const NEUTRAL_SIDE := 31

static var _loaded := false
static var _allies: Dictionary = {}
static var _enemies: Dictionary = {}
static var _assignment: Dictionary = {}


## Forgets what was read; the next question reads `path` again.
static func refresh(path := NTTS_PATH) -> void:
	_loaded = true
	_allies = {}
	_enemies = {}
	_assignment = {}
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		set_rows(parsed.get("sides", []))


## `rows`: [{id, allies, enemies, assignment}] as the exporter writes them.
static func set_rows(rows: Array) -> void:
	_loaded = true
	_allies = {}
	_enemies = {}
	_assignment = {}
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var id := int(row.get("id", -1))
		_allies[id] = int(row.get("allies", 0))
		_enemies[id] = int(row.get("enemies", 0))
		_assignment[id] = int(row.get("assignment", 0))


static func side_of(slot: int) -> int:
	return slot - 1 if slot > 0 else NEUTRAL_SIDE


static func slot_of(side: int) -> int:
	return side + 1 if side != NEUTRAL_SIDE else 0


## True when the map describes both sides (otherwise the old rule applies).
static func knows(slot_a: int, slot_b: int) -> bool:
	_ensure()
	return _enemies.has(side_of(slot_a)) and _enemies.has(side_of(slot_b))


static func stance(from_slot: int, to_slot: int) -> Stance:
	if from_slot == to_slot:
		return Stance.ALLY
	_ensure()
	if not knows(from_slot, to_slot):
		return Stance.ENEMY
	var from_side := side_of(from_slot)
	var bit := 1 << side_of(to_slot)
	if int(_allies.get(from_side, 0)) & bit:
		return Stance.ALLY
	if int(_enemies.get(from_side, 0)) & bit:
		return Stance.ENEMY
	return Stance.NEUTRAL


static func is_enemy(from_slot: int, to_slot: int) -> bool:
	return stance(from_slot, to_slot) == Stance.ENEMY


## A side of the map no player takes (assignment 0 and not the neutral side): Farmers and Taurocks.
static func is_npc_slot(slot: int) -> bool:
	_ensure()
	var side := side_of(slot)
	return slot > 0 and _assignment.has(side) and int(_assignment[side]) == 0


static func _ensure() -> void:
	if not _loaded:
		refresh()
