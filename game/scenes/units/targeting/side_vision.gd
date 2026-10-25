class_name SideVision
extends Node

## What each side has seen (RFC-024 §3.1, 024b): %Vision in high_noon. sacengine keeps, per side and per
## entity, the last tick it was seen (`lastSeenTick`, state.d:30264); a foe counts as visible to a side for
## 32*60/5 = 384 ticks after the mark (`isVisibleToSide`, state.d:29689-29693), a building or a soul for good
## (`frame+1000000`, state.d:29668). Marks come from `markVisibleNTTs` (state.d:12901): every tick the
## creature at the front of its side's queue marks the foes within its sight range (state.d:13650-13652,
## the queue pops one creature per side per tick, state.d:29349-29352). The victim's side also sees whoever
## hurt it (dealDamage, state.d:8902).
##
## Approximations («aprox.»): no field of view (sightFov and alertness are not exported) and no terrain
## line of sight (`fogOfWar` is off by default in sacengine, options.d:93, which skips it too). Buildings do
## not observe: the port has no sight range for them. Everything runs in _physics_process.
##
## F165: SideVision is also the one owner of the sight that is not a creature's own, the terrain grid `updateVision` keeps
## (state.d:29699-29744): per side a 256x256 grid of 10 m cells with «seen until tick N» and «explored once». Whoever looks
## from a spot (the Ranger's Divine Sight eye) calls update_vision(); the queries are position_visible_to() /
## position_explored_by(). sacengine reads the grid only with fogOfWar on (off by default, options.d:93) and the port has no
## fog yet, so nothing in the match consumes it: it is the data a fog will draw, and what the F165 flow checks.

## `attacker` hurt `victim`: the victim's TargetPicker listens and remembers who hit it.
signal revealed(attacker: Node3D, victim: Node3D)
## `side` marks `node` for the first time (or again after the mark lapsed): sacengine botSeen hook
## (shiny.d:616-635, on markVisibleNTTs). AiPerception adds the node to what its side knows.
signal marked(side: int, node: Node3D)

const GROUP := &"side_vision"
## sacengine visionGridSize (state.d:30255): cells per side of the terrain sight grid, 10 m each (DangerGrid.coord).
const GRID := 256
const CELL_M := 10.0
## sacengine updateVision `refresh` = updateFPS / 2 (state.d:29703): a cell stays seen this many ticks after it was lit.
const REFRESH_TICKS := 30
## 32 * updateFPS / 5 (state.d:29692).
const SEEN_TICKS := 384
## frame + 1000000 in sacengine: a permanent mark.
const PERMANENT := 1000000

## Bodies that look: one per side per tick, in turn.
@export var observer_groups: PackedStringArray = PackedStringArray(["unit", "wizard"])
## Bodies that can be seen.
@export var seen_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "structure", "doctor", "manafount"])
## A wizard has no sight range in the exported data: aprox. like a creature of the roster.
@export var wizard_sight_m := 100.0
## Time between purges of the marks of bodies that no longer exist.
@export_range(0.0166, 600.0, 0.0001, "suffix:s") var purge_s := 10.0
## RFC-049 049c: the rules that say if the allies share what they see (MatchRules.allied_vision). Empty = the ones of the world that
## holds this node (its `rules`), else shared.
@export var rules: MatchRules

var tick := 0
## Wall-clock microseconds of the last tick and their sum, for the report (never read by the simulation).
var last_us := 0
var total_us := 0

var _seen: Dictionary = {}
var _cursor: Dictionary = {}
## side -> PackedInt32Array(GRID * GRID): the tick until which each cell is seen (sacengine visionCounters, kept as a deadline
## so nothing counts down per tick). side -> PackedByteArray(GRID * GRID): 1 once the cell was ever seen (exploredTerrain).
var _sight_until: Dictionary = {}
var _explored: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	tick += 1
	var by_side := {}
	for group in observer_groups:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not _can_look(body):
				continue
			var slot := int(body.get("owner_slot"))
			if slot <= 0:
				continue
			if not by_side.has(slot):
				by_side[slot] = []
			by_side[slot].append(body)
	for slot in by_side:
		var list: Array = by_side[slot]
		var next := (int(_cursor.get(slot, -1)) + 1) % list.size()
		_cursor[slot] = next
		observe(list[next])
	if tick % maxi(1, MatchClock.ticks_for(purge_s)) == 0:
		_purge()
	last_us = Time.get_ticks_usec() - started
	total_us += last_us


## The foes within the sight range of `observer` are marked as seen by its side.
func observe(observer: Node3D) -> void:
	var slot := int(observer.get("owner_slot"))
	var sight := sight_of(observer)
	if sight <= 0.0:
		return
	var here := observer.global_position
	for group in seen_groups:
		for node in get_tree().get_nodes_in_group(group):
			var other := node as Node3D
			if other == null or other == observer:
				continue
			var at := other.global_position
			if Vector2(at.x - here.x, at.z - here.z).length() > sight:
				continue
			## The manafounts are neutral buildings: sacengine marks every building in sight, not only the enemy's, and the AI needs it
			## to learn that a fount was taken (RFC-024 024d: its status is refreshed only on what the side has seen).
			if other.is_in_group("manafount") or TargetRules.is_valid_foe_of(slot, other, observer):
				mark(slot, other)


## `side` saw `node` now (buildings for good). With allied vision (sacengine markAsVisible, state.d:29658-29665) its allies saw it too.
func mark(side: int, node: Node3D) -> void:
	if side <= 0 or node == null:
		return
	_mark_one(side, node)
	if _allied_vision():
		for ally in SideRelations.allies_of(side):
			_mark_one(ally, node)


func _allied_vision() -> bool:
	var source: Variant = rules
	if source == null:
		var holder := get_parent()
		source = holder.get("rules") if holder != null else null
	return not source is MatchRules or (source as MatchRules).allied_vision


func _mark_one(side: int, node: Node3D) -> void:
	if not _seen.has(side):
		_seen[side] = {}
	var permanent := node.is_in_group("structure") or node.is_in_group("manafount")
	var fresh: bool = not (_seen[side] as Dictionary).has(node.get_instance_id())
	_seen[side][node.get_instance_id()] = tick + (PERMANENT if permanent else 0)
	if fresh:
		marked.emit(side, node)


## sacengine dealDamage: the side of the victim sees the attacker.
func reveal(attacker: Node3D, victim: Node3D) -> void:
	if attacker == null or victim == null:
		return
	mark(int(victim.get("owner_slot")), attacker)
	revealed.emit(attacker, victim)


## sacengine isVisibleToSide: your own side always; a foe within 384 ticks of its last mark.
func is_visible_to(side: int, node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if int(node.get("owner_slot")) == side:
		return true
	var last := last_seen_tick(side, node)
	return last >= 0 and tick - last < SEEN_TICKS


## -1: never seen by `side`.
func last_seen_tick(side: int, node: Node3D) -> int:
	if not _seen.has(side):
		return -1
	return int(_seen[side].get(node.get_instance_id(), -1))


## How many marks `side` holds.
func seen_count(side: int) -> int:
	return (_seen[side] as Dictionary).size() if _seen.has(side) else 0


func sight_of(observer: Node3D) -> float:
	if observer.is_in_group("wizard"):
		return wizard_sight_m
	var type: Variant = observer.get("type")
	return float(type.sight_m) if type != null else 0.0


## Alive, summoned and not held: what sacengine requiresAI(mode) lets look.
func _can_look(body: Node3D) -> bool:
	if body.has_method("is_dead") and body.call("is_dead"):  # dynamic: unit, structure and doctor bodies answer it
		return false
	if body is UnitBody and ((body as UnitBody).is_summoning() or (body as UnitBody).is_taken()):
		return false
	return true


func _purge() -> void:
	for side in _seen:
		var marks: Dictionary = _seen[side]
		for id in marks.keys():
			if not is_instance_id_valid(id):
				marks.erase(id)


## sacengine updateVision (state.d:29699-29744), for the sight that comes from a spot and not from a body's own range: lights the
## cells of `side`'s grid whose center lies within `radius` m (flat) of `center`, through tick + REFRESH_TICKS, and marks them explored.
## The caller picks how often (sacengine: every REFRESH_TICKS ticks per source, (id + frame) % refresh). Approximation (declared,
## like observe()): no terrain line of sight (the original ray-casts from the eye to each cell). Server (or solo) only.
## Returns how many cells it lit.
func update_vision(side: int, center: Vector3, radius: float) -> int:
	if side <= 0 or radius <= 0.0:
		return 0
	if not _sight_until.has(side):
		var until := PackedInt32Array()
		until.resize(GRID * GRID)
		_sight_until[side] = until
		var seen_once := PackedByteArray()
		seen_once.resize(GRID * GRID)
		_explored[side] = seen_once
	var until: PackedInt32Array = _sight_until[side]
	var seen_once: PackedByteArray = _explored[side]
	var cx := cell_of(center.x)
	var cy := cell_of(center.z)
	var reach := maxi(1, int(0.1 * radius))
	var radius_sq := radius * radius
	var lit := 0
	for dy in range(-reach, reach + 1):
		var y := cy + dy
		if y < 0 or y >= GRID:
			continue
		for dx in range(-reach, reach + 1):
			var x := cx + dx
			if x < 0 or x >= GRID:
				continue
			var off_x := CELL_M * x - center.x
			var off_y := CELL_M * y - center.z
			if off_x * off_x + off_y * off_y > radius_sq:
				continue
			var index := y * GRID + x
			if until[index] < tick + REFRESH_TICKS:
				until[index] = tick + REFRESH_TICKS
			seen_once[index] = 1
			lit += 1
	return lit


## sacengine DangerGrid.coord: the cell a world coordinate falls in (cells are centered on multiples of 10 m).
static func cell_of(meters: float) -> int:
	return clampi(int(0.1 * (meters + 5.0)), 0, GRID - 1)


## sacengine positionVisibleToSide (state.d:29745-29750) with the fog on: the cell under `at` is lit for `side` now.
func position_visible_to(side: int, at: Vector3) -> bool:
	if not _sight_until.has(side):
		return false
	return _lit(int((_sight_until[side] as PackedInt32Array)[cell_of(at.z) * GRID + cell_of(at.x)]))


## sacengine positionExploredBySide (state.d:29751-29756) with the fog on: the cell was lit at some point.
func position_explored_by(side: int, at: Vector3) -> bool:
	if not _explored.has(side):
		return false
	return int((_explored[side] as PackedByteArray)[cell_of(at.z) * GRID + cell_of(at.x)]) != 0


## How many cells `side` sees now.
func visible_cell_count(side: int) -> int:
	if not _sight_until.has(side):
		return 0
	var count := 0
	for deadline in (_sight_until[side] as PackedInt32Array):
		if _lit(deadline):
			count += 1
	return count


## A cell with deadline `until` (0 = never lit) is seen through that tick.
func _lit(until: int) -> bool:
	return until > 0 and until >= tick
