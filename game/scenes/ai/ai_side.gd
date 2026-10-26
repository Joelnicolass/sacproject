@tool
class_name AiSide
extends Node

## One AI side: its seat becomes what it plays with (AiPlay), every child gets it once, and each physics tick the child Clock says
## which of the six jobs run (status, stance, perception, groups, replan, tasks). The decisions are in the children and all that
## leaves goes through the port. Runs only where the game is simulated (solo or the server); the bench starts it paused (`active`
## off). Take away a child and that behaviour is gone. What a human reads of it is AiSideReport. Ref: shiny.d:459-500 run.

signal started

@export var slot := 2
@export var seat: AiSeat
@export var active := false:
	set(value):
		active = value
		if value and is_node_ready():
			_start.call_deferred()
@export var clock: AiClock
@export var perception: AiPerception
@export var stance: AiStance
@export var groups: AiGroups
@export var board: AiTaskBoard
@export var brain: AiWizardBrain
@export var creature_brain: CreatureBrain
@export var port: AiCommandPort
@export var audit: AiAudit

## What this side plays with (tactics, difficulty, aggression, ages): made once by setup, shared by every child.
var play: AiPlay
var wizard: Node3D
var world: Node3D

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
	for pair in [["clock", clock], ["perception", perception], ["stance", stance], ["groups", groups], ["board", board], ["brain", brain], ["port", port]]:
		if pair[1] == null:
			warnings.append("Falta el hijo `%s`." % pair[0])
	return warnings


## Gives the side its world and its wizard (the roster or the bench does it). Call before `active`.
func setup(world_node: Node3D, wizard_body: Node3D, ai_seat: AiSeat) -> void:
	world = world_node
	wizard = wizard_body
	seat = ai_seat
	slot = ai_seat.slot
	play = AiPlay.make(ai_seat.difficulty_or_normal(), ai_seat.tactics, clock.base_ticks(AiClock.Job.PERCEPTION))
	clock.play = play
	perception.play = play
	stance.play = play
	board.play = play
	brain.play = play
	port.orders.play = play
	if creature_brain != null:
		creature_brain.play = play
	if ai_seat.book != null and wizard is WizardBody:  # a bench's or a solo game's own book: it does not travel on the network
		if MpKit.is_networked():
			push_warning("AiSide: AiSeat.book no viaja por red (slot %d)" % slot)
		(wizard as WizardBody).book = ai_seat.book
	perception.slot = slot
	perception.wizard = wizard
	perception.belief.look_from(wizard, play.difficulty.knowledge, play.tactics.senses.map_sight_m)
	port.delay_ticks = play.difficulty.delay_ticks(Engine.physics_ticks_per_second)
	port.can_cast = brain.casting.cast_refusal
	brain.prepare()
	port.bind(slot, wizard, world.get_node("%Orders"))
	port.audit = audit
	brain.rng = AiRand.with_seed(MatchSeed.derive(["ai_rand", slot]) if MatchSeed.is_active() else 1)
	perception.forced.connect(clock.wake)
	clock.job_due.connect(_run_job)
	## A creature the side summons, or a structure it builds (a Manalith), is one of its own bodies from the moment it stands.
	for parent: Node in [world.get_node_or_null("%Units"), world.get_node_or_null("Structures")]:
		if parent != null:
			parent.child_entered_tree.connect(_on_unit_entered)
	if audit != null:
		audit.watch_ai(slot, wizard, perception)


func _start() -> void:
	if _started or wizard == null:
		return
	_started = true
	started.emit()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not active or not _started:
		return
	var began := Time.get_ticks_usec()
	var game_before := port.game_us
	## The requests that waited their delay (Easy) leave first: what the wizard decided half a second ago.
	port.flush()
	for node in _arrived:
		if is_instance_valid(node):
			perception.add_node(node, &"event")
	_arrived.clear()
	clock.run()
	clock.note_tick(Time.get_ticks_usec() - began, port.game_us - game_before)


## What each job of the clock does, in the children. Ref: shiny.d:1129-1172 updateStatus, 1305-1346 updateReplan.
func _run_job(job: int) -> void:
	match job:
		AiClock.Job.STATUS:
			# the first scan of the map and the stats, when something woke them
			if clock.is_woken(AiClock.Wake.STANCE): clock.handle(AiClock.Wake.STANCE)
			if clock.is_woken(AiClock.Wake.SCAN):
				perception.scan_global()
				clock.handle(AiClock.Wake.SCAN)
			if clock.is_woken(AiClock.Wake.STATS):
				perception.update_stats()
				clock.handle(AiClock.Wake.STATS)
		AiClock.Job.STANCE: stance.update()
		AiClock.Job.PERCEPTION:
			perception.update_nodes(1)
			stance.update_threat(perception.find(wizard))
		AiClock.Job.GROUPS: groups.refresh()
		AiClock.Job.REPLAN:
			# bodies, groups, tasks and claims made again
			perception.discover()
			perception.sort_bodies()
			groups.rebuild()
			board.replan_tasks()
			board.claim_pass()
			clock.handle(AiClock.Wake.REPLAN | AiClock.Wake.TASKS)
		AiClock.Job.TASKS: board.update_tasks()


## A creature (or a structure) of the side appeared: summoned, built, or put by the scene. Ref: shiny.d:575-584 botSpawned.
func _on_unit_entered(node: Node) -> void:
	if int(node.get("owner_slot")) != slot:
		return
	_arrived.append(node as Node3D)
