class_name MpLobbyClient
extends Node

## Client side of the lobby protocol. Keeps a mirror of what the room server says (`rooms`, `room`,
## `chat_log`) and speaks in past-tense signals. The UI only reads this node and calls its commands.
## Lives under a `MpLobby` container (own `SceneMultiplayer`): it stays connected to the lobby while
## `MpKit` joins the match process, so the result arrives here too. Nothing here knows the game.

enum Link { OFFLINE, CONNECTING, ONLINE }

## The server accepted us (new session or resumed).
signal lobby_joined(session_id: String)
## The connection ended or never opened. `reason`: connect_failed, server_lost, closed.
signal lobby_lost(reason: String)
## The server refused the hello (version, bad_name, timeout). The link is closed.
signal rejected(code: String)
signal room_list_received(rows: Array)
## The mirror of our room changed (full state, never a delta).
signal room_updated(room: Dictionary)
signal room_left
signal chat_received(seat: int, display_name: String, text: String)
## The room went from not-counting to counting. `seconds` is what was left when it arrived.
signal countdown_started(seconds: float)
signal countdown_cancelled
## Where to connect: `host` is empty when the server did not name one (use the lobby host).
signal match_ready(host: String, port: int, token: String)
signal match_finished(result: Dictionary)
## A command was refused or something failed (stable code).
signal error_received(code: String)

## Set by the container: the sibling `MpLobbyServer`.
@export var server_node: Node
@export var chat_keep: int = 50
## Used in the hello; must equal the server's `MpLobbyConfig.proto_version`.
@export var proto_version: int = 1

var link: int = Link.OFFLINE
var session_id: String = ""
var resume_token: String = ""
var display_name: String = ""
var rooms: Array = []
var room: Dictionary = {}
var chat_log: Array = []
var last_error: String = ""
var host: String = ""
var port: int = 0

var _peer: ENetMultiplayerPeer
var _signals_ready: bool = false
var _countdown_end_msec: int = 0
var _result_key: int = 0
## Match connection data kept until the next one (the UI may read it after the signal).
var _last_match: Dictionary = {}


func _ready() -> void:
	_ensure_signals()


func is_online() -> bool:
	return link == Link.ONLINE


## Seconds left of the room countdown (0 if none).
func countdown_remaining() -> float:
	if _countdown_end_msec <= 0:
		return 0.0
	return maxf(0.0, float(_countdown_end_msec - Time.get_ticks_msec()) / 1000.0)


## Our seat in the current room, -1 if none.
func my_seat() -> int:
	for seat: Dictionary in room.get("seats", []):
		if bool(seat.get("you", false)):
			return int(seat["seat"])
	return -1


func last_match() -> Dictionary:
	return _last_match.duplicate()


## New session. Forgets the previous one.
func connect_to(p_host: String, p_port: int, p_display_name: String) -> Error:
	close_connection()
	session_id = ""
	resume_token = ""
	rooms = []
	room = {}
	chat_log = []
	_countdown_end_msec = 0
	_result_key = 0
	host = p_host
	port = p_port
	display_name = p_display_name
	return _open()


## Reconnects to the same server with the saved token: same session, same seat.
func resume() -> Error:
	if host.is_empty() or port <= 0:
		return ERR_UNCONFIGURED
	close_connection()
	return _open()


func close_connection() -> void:
	_ensure_signals()
	link = Link.OFFLINE
	if _peer == null:
		return
	var closing := _peer
	_peer = null
	closing.close()
	if multiplayer.multiplayer_peer == closing:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func refresh_rooms() -> void:
	_send(&"rpc_list_rooms", [])


func create_room(room_name: String, is_private: bool = false, options: Dictionary = {}) -> void:
	_send(&"rpc_create_room", [room_name, is_private, options])


func join_room(room_id: String) -> void:
	_send(&"rpc_join_room", [room_id])


func join_code(code: String) -> void:
	_send(&"rpc_join_code", [code])


func leave_room() -> void:
	_send(&"rpc_leave_room", [])


func choose_seat(seat: int) -> void:
	_send(&"rpc_set_slot", [seat])


## The pick of our seat (opaque Dictionary; the server's validator decides).
func set_pick(pick: Dictionary) -> void:
	_send(&"rpc_set_pick", [pick])


func set_ready(on: bool) -> void:
	_send(&"rpc_set_ready", [on])


func send_chat(text: String) -> void:
	_send(&"rpc_chat", [text])


# --- internals -------------------------------------------------------------------------

func _ensure_signals() -> void:
	if _signals_ready:
		return
	_signals_ready = true
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _open() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	link = Link.CONNECTING
	return OK


func _send(method: StringName, args: Array) -> void:
	if link != Link.ONLINE or server_node == null:
		return
	server_node.callv(&"rpc_id", [1, method] + args)


func _on_connected() -> void:
	if _peer == null or server_node == null:
		return
	server_node.callv(&"rpc_id", [1, &"rpc_hello", proto_version, display_name, resume_token])


func _on_connection_failed() -> void:
	if _peer == null:
		return
	close_connection()
	lobby_lost.emit("connect_failed")


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	close_connection()
	lobby_lost.emit("server_lost")


@rpc("authority", "call_remote", "reliable")
func rpc_welcome(p_session_id: String, p_resume_token: String) -> void:
	session_id = p_session_id
	resume_token = p_resume_token
	link = Link.ONLINE
	lobby_joined.emit(session_id)


@rpc("authority", "call_remote", "reliable")
func rpc_rejected(code: String) -> void:
	last_error = code
	close_connection()
	rejected.emit(code)


@rpc("authority", "call_remote", "reliable")
func rpc_room_list(rows: Array) -> void:
	rooms = rows
	room_list_received.emit(rooms)


@rpc("authority", "call_remote", "reliable")
func rpc_room_state(view: Dictionary) -> void:
	var prev := room
	room = view
	if view.is_empty():
		_countdown_end_msec = 0
		if not prev.is_empty():
			chat_log = []
			room_left.emit()
		return
	var new_room := str(prev.get("id", "")) != str(view["id"])
	if new_room:
		chat_log = []
		_result_key = (view["last_result"] as Dictionary).hash()
	var was_counting := int(prev.get("state", -1)) == MpLobbyRooms.State.COUNTDOWN and not new_room
	var state := int(view["state"])
	if state == MpLobbyRooms.State.COUNTDOWN:
		_countdown_end_msec = Time.get_ticks_msec() + int(float(view["countdown_left"]) * 1000.0)
	else:
		_countdown_end_msec = 0
	room_updated.emit(room)
	if state == MpLobbyRooms.State.COUNTDOWN and not was_counting:
		countdown_started.emit(float(view["countdown_left"]))
	elif was_counting and state == MpLobbyRooms.State.OPEN:
		countdown_cancelled.emit()
	var result: Dictionary = view["last_result"]
	if not result.is_empty() and result.hash() != _result_key:
		_result_key = result.hash()
		match_finished.emit(result.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func rpc_chat_line(seat: int, who: String, text: String) -> void:
	chat_log.append({"seat": seat, "name": who, "text": text})
	while chat_log.size() > chat_keep:
		chat_log.pop_front()
	chat_received.emit(seat, who, text)


@rpc("authority", "call_remote", "reliable")
func rpc_match_ready(p_host: String, p_port: int, token: String) -> void:
	var use_host := p_host if not p_host.is_empty() else host
	_last_match = {"host": use_host, "port": p_port, "token": token}
	match_ready.emit(use_host, p_port, token)


@rpc("authority", "call_remote", "reliable")
func rpc_error(code: String) -> void:
	last_error = code
	error_received.emit(code)
