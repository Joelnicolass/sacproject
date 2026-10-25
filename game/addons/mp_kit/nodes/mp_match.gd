class_name MpMatch
extends Node

## Drop one in the world for the start and the end of a match. On the server it says when everyone is in, who left,
## who came back and who gave up; `finish(result)` ends the match for every peer (`finished` everywhere). In a match
## started by the online lobby it also holds the world until every seat loaded and writes the result for the room.
## Not: the rules that decide who won (your game calls finish), the lobby screen, scoring (MpState).

## Server: every seat is here and loaded (a lobby match), or the world is ready (LAN, dedicated, solo).
signal all_loaded
signal player_joined(slot: int)
signal player_left(slot: int)
## Server, lobby match: a player who left came back within the grace (same slot).
signal player_back(slot: int)
## Server, lobby match: a player stayed away longer than the grace, or never loaded. Decide what it means.
signal player_abandoned(slot: int)
## Every peer: the server called finish(result).
signal finished(result: Dictionary)

## Lobby match: keep the world paused until every seat loaded (or load_timeout_s of MpLobbyConfig passed).
@export var pause_until_loaded: bool = true

## The MpMatchAgent of a lobby match (found by group, untyped: a world node must not load the lobby scripts).
var _agent: Node
var _ticket: Dictionary = {}
var _load_timeout_s: float = 60.0
var _rejoin_grace_s: float = 60.0
var _expected: Array[int] = []
var _loaded: Dictionary = {}
var _away_ms: Dictionary = {}
var _seen: Dictionary = {}
var _gone: Dictionary = {}
var _all_sent: bool = false
var _start_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MpKit.session_ended.connect(_on_session_ended)
	if not MpKit.is_authority():
		return
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.peer_left.connect(_on_peer_left)
	MpKit.client_world_ready.connect(_on_world_ready)
	var agents := get_tree().get_nodes_in_group(&"mp_match_agent")
	_agent = agents[0] if not agents.is_empty() else null
	_ticket = _agent.get("ticket") if _agent else {}
	if _ticket.is_empty():
		_agent = null
		_all_loaded.call_deferred()
		return
	var config: Resource = _agent.get("config")
	if config:
		_load_timeout_s = float(config.get("load_timeout_s"))
		_rejoin_grace_s = float(config.get("rejoin_grace_s"))
	for row in _ticket.get("seats", []):
		if not str((row as Dictionary).get("token_sha256", "")).is_empty():
			_expected.append(int(row["slot"]))
	_start_ms = Time.get_ticks_msec()
	for peer_id in multiplayer.get_peers():
		if MpKit.is_peer_world_ready(peer_id):
			_loaded[MpKit.slot_for_peer(peer_id)] = true
	if pause_until_loaded:
		get_tree().paused = true
	_check_loaded()


func _exit_tree() -> void:
	if get_tree().paused and _agent:
		get_tree().paused = false


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


## Server: the slots of the lobby ticket (empty outside a lobby match).
func seats() -> Array[int]:
	return _expected.duplicate()


func _process(_delta: float) -> void:
	if _agent == null or _expected.is_empty():
		return
	var now := Time.get_ticks_msec()
	if not _all_sent and now - _start_ms > int(_load_timeout_s * 1000.0):
		for slot in _expected:
			if not _loaded.has(slot):
				_give_up(slot)
		_send_all_loaded()
	for slot in _away_ms.keys():
		if now - int(_away_ms[slot]) > int(_rejoin_grace_s * 1000.0):
			_away_ms.erase(slot)
			_give_up(slot)


func _on_peer_joined(_peer_id: int, slot: int) -> void:
	if _away_ms.erase(slot):
		player_back.emit(slot)
		return
	if not _seen.has(slot):
		_seen[slot] = true
		player_joined.emit(slot)


func _on_peer_left(_peer_id: int, slot: int) -> void:
	if slot <= 0:
		return
	player_left.emit(slot)
	if _expected.has(slot) and not _gone.has(slot):
		_away_ms[slot] = Time.get_ticks_msec()


func _on_world_ready(peer_id: int) -> void:
	_loaded[MpKit.slot_for_peer(peer_id)] = true
	_check_loaded()


func _check_loaded() -> void:
	if _all_sent:
		return
	for slot in _expected:
		if not _loaded.has(slot):
			return
	_send_all_loaded()


func _send_all_loaded() -> void:
	if _all_sent:
		return
	_all_sent = true
	get_tree().paused = false
	all_loaded.emit()


func _all_loaded() -> void:
	_send_all_loaded()


func _give_up(slot: int) -> void:
	if _gone.has(slot):
		return
	_gone[slot] = true
	player_abandoned.emit(slot)


func _on_session_ended(result: Dictionary) -> void:
	if not MpKit.is_authority():
		finished.emit(result)
