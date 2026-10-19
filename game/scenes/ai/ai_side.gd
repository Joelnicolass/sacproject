@tool
class_name AiSide
extends Node

## One AI side (RFC-024 §3.1 `AiSide`; shiny.d:459-500 `run`, 504-514 `scheduler`): the clock of the six slots and nothing else.
##   k0 every 12 ticks  updateStatus  (first scan of the map, stats)        k3 every  6  updateGroups
##   k1 every 60        updateStance                                        k4 every 60  updateReplan (groups, tasks, claims)
##   k2 every  6        updateNtts    (the bodies it follows, the threat)   k5 every 12  updateTasks (the brains think)
## An event of the game can force a slot ahead of its time (`forceFlags`, shiny.d:517-546). Every slot gets dTicks = 1 as
## the original does (so a body's «age» counts runs of k2). The decisions are in the children: perception, stance, groups,
## board, brains; and all that leaves goes through the port. Runs only where the game is simulated (solo or the server).
## It measures the milliseconds each tick takes (`ai_ms`, never read by the simulation). Take away a child and that
## behaviour is gone. The scenes of the bench start it paused (`active` off).

signal started

## shiny.d:469: which force bits make each slot run before its period.
const FORCE_MASKS: Array[int] = [0xe, 0xf, 1, 1, 0x3f, 1]

@export var slot := 2
@export var seat: AiSeat
@export var active := false:
	set(value):
		active = value
		if value and is_node_ready():
			_start.call_deferred()
@export var perception: AiPerception
@export var stance: AiStance
@export var groups: AiGroups
@export var board: AiTaskBoard
@export var brain: AiWizardBrain
@export var creature_brain: CreatureBrain
@export var port: AiCommandPort
@export var audit: AiAudit

var profile: AiProfile
## The difficulty it plays (024e): set by setup from the seat.
var difficulty: AiDifficulty
var wizard: Node3D
var world: Node3D
var ticks := 0
var force_flags := 0xf
var handled_flags := 0
## First tick of each slot. sacengine starts all six at the same tick, so every 60th tick runs the six together (a spike of ~2 ms);
## k3 and k5 start a few ticks late (3 and 6): the same periods, the same order, the work spread over more ticks. 024e: k2 (updateNtts,
## ~0.5 ms with 60 bodies) starts at 1, so it no longer falls on the ticks of k4 (every 60) and k5 (6 + 12n): measured in ai_perf60,
## the k2+k4 ticks were the 1.7 % of ticks that set the p99 (~2 ms).
var next_run: Array[int] = [0, 0, 1, 3, 0, 6]
var tick_ms := PackedFloat32Array()
## The same ticks without the calls into the game the tick made through the port (a summon instantiates a creature, an order plans a
## path: that cost is the game's, the same a human's click has). What is left is the cost of the decisions.
var tick_ms_decisions := PackedFloat32Array()
## Diagnostic (024e, never read by the simulation): microseconds of each run of each slot k0..k5, and the slowest tick with the slots
## it ran and what of it was spent inside the game, for the report (`ai_slot_ms`).
var slot_us: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
var worst := {}
var _tick_slots := {}

var _started := false
## Own bodies that entered the tree since the last tick: the tick takes them in (everything happens in the physics frame).
var _arrived: Array[Node3D] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	if active:
		_start.call_deferred()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for pair in [["perception", perception], ["stance", stance], ["groups", groups], ["board", board], ["brain", brain], ["port", port]]:
		if pair[1] == null:
			warnings.append("Falta el hijo `%s`." % pair[0])
	return warnings


## Gives the side its world and its wizard (the roster does it; in 024c the debug scenes). Call before `active`.
func setup(world_node: Node3D, wizard_body: Node3D, ai_seat: AiSeat) -> void:
	world = world_node
	wizard = wizard_body
	seat = ai_seat
	slot = ai_seat.slot
	difficulty = ai_seat.difficulty_or_normal()
	## 024e: the difficulty scales the periods and sets the aggression on a copy of the god's profile; the .tres are never changed.
	profile = difficulty.apply_to(ai_seat.profile if ai_seat.profile != null else AiProfile.for_god(ai_seat.god))
	for node: Node in [perception, stance, groups, board, brain, creature_brain]:
		node.set("profile", profile)
	perception.slot = slot
	perception.wizard = wizard
	perception.perfect_information = difficulty.perfect_information
	port.delay_ticks = difficulty.delay_ticks(Engine.physics_ticks_per_second)
	brain.summon_interval_ticks = difficulty.summon_interval_ticks(Engine.physics_ticks_per_second)
	brain.mana_reserve = difficulty.mana_reserve
	port.can_cast = brain.cast_refusal
	brain.prepare()
	port.bind(slot, wizard, world.get_node("%Orders"))
	port.audit = audit
	port.perception = perception
	brain.rng = AiRand.with_seed(MatchSeed.derive(["ai_rand", slot]) if MatchSeed.is_active() else 1)
	perception.forced.connect(_on_forced)
	var units := world.get_node_or_null("%Units")
	if units != null:
		units.child_entered_tree.connect(_on_unit_entered)
	## A structure the side builds (a Manalith) is one of its own bodies from the moment it stands (botSpawned: shiny.d:575-584).
	var structures := world.get_node_or_null("Structures")
	if structures != null:
		structures.child_entered_tree.connect(_on_unit_entered)
	if audit != null:
		audit.watch_ai(slot, wizard, perception)


func _start() -> void:
	if _started or wizard == null:
		return
	_started = true
	perception.begin()
	started.emit()


func is_running() -> bool:
	return _started and active


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not active or not _started:
		return
	var began := Time.get_ticks_usec()
	var game_before := port.game_us
	## The requests that waited their delay (Easy) leave first: what the wizard decided half a second ago.
	port.flush()
	_run()
	var spent := Time.get_ticks_usec() - began
	if spent > int(worst.get("us", 0)):
		worst = {"tick": ticks - 1, "us": spent, "game_us": port.game_us - game_before, "slots": _tick_slots.duplicate()}
	_tick_slots.clear()
	tick_ms.append(float(spent) / 1000.0)
	tick_ms_decisions.append(float(spent - (port.game_us - game_before)) / 1000.0)


## run (shiny.d:459-488).
func _run() -> void:
	for node in _arrived:
		if is_instance_valid(node):
			perception.add_node(node, &"event")
	_arrived.clear()
	handled_flags = 0
	for k in 6:
		if next_run[k] <= ticks:
			_slot(k)
			next_run[k] += profile.slot_periods[k]
		elif (force_flags & FORCE_MASKS[k]) != 0:
			_slot(k)
	force_flags &= ~handled_flags
	ticks += 1


func _slot(k: int) -> void:
	var began := Time.get_ticks_usec()
	_run_slot(k)
	slot_us[k].append(Time.get_ticks_usec() - began)
	_tick_slots["k%d" % k] = Time.get_ticks_usec() - began


func _run_slot(k: int) -> void:
	match k:
		0:
			_update_status()
		1:
			stance.update()
		2:
			perception.update_nodes(1)
			stance.update_threat(perception.find(wizard))
		3:
			groups.refresh()
		4:
			_update_replan()
		5:
			board.update_tasks()


## updateStatus (shiny.d:1129-1172): the first scan of the map and the stats.
func _update_status() -> void:
	if force_flags & 4:
		handled_flags |= 4
	if force_flags & 8:
		perception.scan_global()
		handled_flags |= 8
	if force_flags & 2:
		perception.update_stats()
		handled_flags |= 2


## updateReplan (shiny.d:1305-1346).
func _update_replan() -> void:
	perception.discover()
	perception.sort_bodies()
	groups.rebuild()
	board.replan_tasks()
	board.claim_pass()
	handled_flags |= 1 | 0x20


func _on_forced(bits: int) -> void:
	force_flags |= bits


## botSpawned (shiny.d:575-584): a creature (or a structure) of the side appeared (summoned, built, or put by the scene).
func _on_unit_entered(node: Node) -> void:
	if int(node.get("owner_slot")) != slot:
		return
	_arrived.append(node as Node3D)


## Mean, p99 and max of the milliseconds a tick of the side took: whole (the criterion, RFC-024 addendum 1.2) and, under
## `decisions`, without the calls into the game it made through the port (diagnostic).
func ms_stats() -> Dictionary:
	if tick_ms.is_empty():
		return {}
	var out := _stats_of(tick_ms)
	out["decisions"] = _stats_of(tick_ms_decisions)
	var over := 0
	var over_game := 0
	for i in tick_ms.size():
		if tick_ms[i] > 2.0:
			over += 1
			if tick_ms[i] - tick_ms_decisions[i] > 1.0:
				over_game += 1
	## ticks over 2 ms, and how many of them spent more than 1 ms inside the game (a summon, a wizard's long path)
	out["over_2ms"] = over
	out["over_2ms_game"] = over_game
	## the first second holds the scan of the map (scanGlobal) and the first orders of every body: the max without it
	if tick_ms.size() > 60:
		out["max_after_1s"] = snappedf(Array(tick_ms.slice(60)).max(), 0.001)
	return out


## Per slot k0..k5: runs, mean, p99 and max in ms (diagnostic).
func slot_stats() -> Dictionary:
	var out := {}
	for k in 6:
		var values := PackedFloat32Array()
		for us in slot_us[k]:
			values.append(float(us) / 1000.0)
		if not values.is_empty():
			out["k%d" % k] = _stats_of(values)
	out["worst_tick"] = worst
	return out


static func _stats_of(values: PackedFloat32Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"mean": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[int(sorted.size() * 0.99)], 0.001),
		"max": snappedf(sorted[sorted.size() - 1], 0.001),
		"ticks": sorted.size(),
	}


## What the side holds right now, for the report and for a human reading it: tracks per category, the records of each task
## with their members, the stance numbers.
func summary() -> Dictionary:
	var tasks := []
	for task in board.tasks:
		var rows := []
		for record in task.records:
			rows.append({"target": str(record.target.node.name) if record.target != null and record.target.is_valid() else "-", "score": ("nan" if is_nan(record.score) else snappedf(record.score, 0.001)), "members": record.members.size(), "leader": str(record.leader.node.name) if record.leader != null and record.leader.is_valid() else "-"})
		tasks.append({"task": task.name, "records": rows})
	var wizard_track := perception.find(wizard)
	return {
		"tracks": [perception.tracks_of(0).size(), perception.tracks_of(1).size(), perception.tracks_of(2).size(), perception.tracks_of(3).size()],
		"manaliths": stance.manalith_count(),
		"souls_all": stance.recs[0].souls_all,
		"enemy_ratio": snappedf(stance.enemy_ratio(), 0.0001),
		"threat": snappedf(wizard_track.threat, 0.0001) if wizard_track != null else -1.0,
		"wizard_age": wizard_track.age if wizard_track != null else -1,
		"groups": [groups.list(0).size(), groups.list(1).size(), groups.list(2).size(), groups.list(3).size()],
		"tasks": tasks,
	}
