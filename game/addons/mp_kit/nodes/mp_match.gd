class_name MpMatch
extends Node

## Drop one in the world for the start and the end of a match. It tells, in the world, what the match's start gate (MpKit.gate)
## says: when everyone is in, who left, who came back and who gave up; `finish(result)` ends the match for every peer (`finished`
## everywhere) and, in a match started by the online lobby, writes the result for the room.
## Not: the wait or the grace (the gate pauses the world and counts them), the rules that decide who won (your game calls
## finish), the lobby screen, scoring (MpState).

## Server: the match starts (every seat it waited for loaded), or the world is ready (solo, no gate).
signal all_loaded
signal player_joined(slot: int)
signal player_left(slot: int)
## Server: a player who left came back within the grace (same slot).
signal player_back(slot: int)
## Server: a player stayed away longer than the grace, or never loaded. Decide what it means.
signal player_abandoned(slot: int)
## Every peer: the server called finish(result).
signal finished(result: Dictionary)
## Every peer: the match waits for seats to load (the world is paused, so nobody walks ahead) or runs.
signal waiting_changed(waiting: bool)

## True while the match waits for its seats (every peer: the server says so).
var waiting: bool:
	get:
		return MpKit.gate.is_waiting()

## The MpMatchAgent of a lobby match (found by group, untyped: a world node must not load the lobby scripts).
var _agent: Node
var _shown_waiting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gate := MpKit.gate
	MpKit.session_ended.connect(_on_session_ended)
	gate.waiting_changed.connect(_on_waiting_changed)
	if not MpKit.is_authority():
		return
	var agents := get_tree().get_nodes_in_group(&"mp_match_agent")
	_agent = agents[0] if not agents.is_empty() and not (agents[0].get("ticket") as Dictionary).is_empty() else null
	gate.seat_admitted.connect(_on_seat_admitted)
	gate.started.connect(_on_started)
	gate.seat_abandoned.connect(_on_seat_abandoned)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.peer_joined.connect(_on_peer_joined)
	if gate.phase != MpMatchGate.Phase.FILLING:
		all_loaded.emit.call_deferred()


## Server (or solo) only: the match is over. Every peer gets `finished(result)`; a lobby match also tells the room.
func finish(result: Dictionary = {}) -> void:
	if not MpKit.is_authority():
		push_warning("MpMatch: finish() only runs on the server")
		return
	if _agent:
		_agent.call(&"report_result", result)
	elif MpKit.is_networked():
		MpKit.broadcast_session_ended(result)
	finished.emit(result)


## Server: the human seats of the match (the gate's; empty solo).
func seats() -> Array[int]:
	return MpKit.gate.expected_slots()


func _on_seat_admitted(slot: int, back: bool) -> void:
	if back:
		player_back.emit(slot)
	else:
		player_joined.emit(slot)


## A server that never armed the gate (no MpFlow): every peer that joins is a new player.
func _on_peer_joined(_peer_id: int, slot: int) -> void:
	if not MpKit.gate.is_armed():
		player_joined.emit(slot)


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if slot > 0:
		player_left.emit(slot)


func _on_started(_why: String) -> void:
	all_loaded.emit()


func _on_seat_abandoned(slot: int, _why: String) -> void:
	player_abandoned.emit(slot)


func _on_waiting_changed(on: bool, _loaded: int, _expected: int) -> void:
	if on == _shown_waiting:
		return
	_shown_waiting = on
	waiting_changed.emit(on)


func _on_session_ended(result: Dictionary) -> void:
	if not MpKit.is_authority():
		finished.emit(result)
