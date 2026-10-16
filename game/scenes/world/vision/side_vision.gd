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

## `attacker` hurt `victim`: the victim's TargetPicker listens and remembers who hit it.
signal revealed(attacker: Node3D, victim: Node3D)
## `side` marks `node` for the first time (or again after the mark lapsed): sacengine botSeen hook
## (shiny.d:616-635, on markVisibleNTTs). AiPerception adds the node to what its side knows.
signal marked(side: int, node: Node3D)

const GROUP := &"side_vision"
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
## Ticks between purges of the marks of bodies that no longer exist.
@export var purge_ticks := 600

var tick := 0
## Wall-clock microseconds of the last tick and their sum, for the report (never read by the simulation).
var last_us := 0
var total_us := 0

var _seen: Dictionary = {}
var _cursor: Dictionary = {}


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
	if tick % purge_ticks == 0:
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
			if other.is_in_group("manafount") or UnitBody.is_valid_foe_of(slot, other, observer):
				mark(slot, other)


## `side` saw `node` now (buildings for good).
func mark(side: int, node: Node3D) -> void:
	if side <= 0 or node == null:
		return
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
	return float(type.sight_range) if type != null else 0.0


## Alive, summoned and not held: what sacengine requiresAI(mode) lets look.
func _can_look(body: Node3D) -> bool:
	if body.has_method("is_dead") and body.call("is_dead"):
		return false
	if body.has_method("is_summoning") and body.call("is_summoning"):
		return false
	if body.has_method("is_taken") and body.call("is_taken"):
		return false
	return true


func _purge() -> void:
	for side in _seen:
		var marks: Dictionary = _seen[side]
		for id in marks.keys():
			if not is_instance_id_valid(id):
				marks.erase(id)
