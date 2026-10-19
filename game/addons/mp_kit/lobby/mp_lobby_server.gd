class_name MpLobbyServer
extends Node

## Room-server side of the lobby protocol. Puts `MpLobbyRooms` on the network (ENet or WebSocket, `config.transport`) and validates
## every client message: version, name, sizes, chat rate, who may do what. A client never picks a
## slot, a port or a seed. Nothing here knows the game: the pick (`meta`), the room `options` and the
## ticket are checked / built by Callables the glue sets before `start()`.
## Lives under a `MpLobby` container (own `SceneMultiplayer`, so it never clashes with `MpKit`).
## Error codes sent to the client: version, bad_name, timeout, bad_text, rate, bad_options, bad_meta, bad_bot, not_host
## and every code of `MpLobbyRooms`.

## A session said hello (new or resumed).
signal session_welcomed(session_id: String, display_name: String)
## The peer of a session went away (the seat stays for `resume_grace_s`).
signal session_lost(session_id: String)

## Set by the container: the sibling `MpLobbyClient` (its RPCs are how the server talks).
@export var client_node: Node

## (meta: Dictionary) -> bool
var meta_validator: Callable = Callable()
## (options: Dictionary) -> bool
var options_validator: Callable = Callable()
## (seats: Array[Dictionary], options: Dictionary) -> Dictionary
var ticket_builder: Callable = Callable()
## (options: Dictionary) -> int, the seats of a room made with these options (default `config.seats_per_room`).
var seat_count_for: Callable = Callable()
## (meta: Dictionary) -> bool, the meta of a bot seat.
var bot_validator: Callable = Callable()

var rooms: MpLobbyRooms
var config: MpLobbyConfig

var _peer: MultiplayerPeer
var _active: bool = false
var _signals_ready: bool = false
## peer id -> session id
var _peer_session: Dictionary = {}
var _session_peer: Dictionary = {}
## session id -> {name, token, chat_tokens, chat_stamp_ms}
var _sessions: Dictionary = {}
var _resume_index: Dictionary = {}
## peer id -> seconds without hello
var _pending: Dictionary = {}
var _subscribed: Dictionary = {}
var _room_names: Dictionary = {}
var _dirty_rooms: Dictionary = {}
var _list_dirty: bool = false
var _list_accum: float = 0.0


func _ready() -> void:
	set_process(false)


func is_active() -> bool:
	return _active


func peer_of(session_id: String) -> int:
	return int(_session_peer.get(session_id, 0))


func session_of_peer(peer_id: int) -> String:
	return str(_peer_session.get(peer_id, ""))


func name_of_room(room_id: String) -> String:
	return str(_room_names.get(room_id, ""))


## Opens the lobby port. `launcher` may be null (the countdown end then gives `spawn_failed`).
func start(p_config: MpLobbyConfig, launcher: MpMatchLauncher = null) -> Error:
	stop()
	config = p_config
	var made := MpTransport.create_server(config.transport, config.lobby_port, config.max_connections)
	var peer := made["peer"] as MultiplayerPeer
	if int(made["error"]) != OK:
		return int(made["error"]) as Error
	rooms = MpLobbyRooms.new(config, launcher)
	rooms.meta_validator = meta_validator
	rooms.options_validator = options_validator
	rooms.ticket_builder = ticket_builder
	rooms.seat_count_for = seat_count_for
	rooms.bot_validator = bot_validator
	rooms.room_changed.connect(_on_room_changed)
	rooms.room_closed.connect(_on_room_closed)
	rooms.match_assigned.connect(_on_match_assigned)
	rooms.room_error.connect(_on_room_error)
	rooms.session_expired.connect(_on_session_expired)
	_peer = peer
	multiplayer.multiplayer_peer = peer
	if not _signals_ready:
		_signals_ready = true
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_active = true
	set_process(true)
	return OK


func stop() -> void:
	if _peer != null:
		var closing := _peer
		_peer = null
		closing.close()
		if multiplayer.multiplayer_peer == closing:
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_active = false
	set_process(false)
	rooms = null
	_peer_session.clear()
	_session_peer.clear()
	_sessions.clear()
	_resume_index.clear()
	_pending.clear()
	_subscribed.clear()
	_room_names.clear()
	_dirty_rooms.clear()
	_list_dirty = false
	_list_accum = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	rooms.tick(delta)
	for peer_id in _pending.keys():
		_pending[peer_id] = float(_pending[peer_id]) + delta
		if float(_pending[peer_id]) >= config.hello_timeout_s:
			_pending.erase(peer_id)
			_reject(int(peer_id), "timeout")
	var dirty := _dirty_rooms.keys()
	_dirty_rooms.clear()
	for room_id in dirty:
		_push_room(str(room_id))
	_list_accum += delta
	if _list_dirty and _list_accum >= 1.0 / maxf(config.list_push_hz, 0.001):
		_list_accum = 0.0
		_list_dirty = false
		for peer_id in _subscribed.keys():
			_send_list(int(peer_id))


# --- connection ------------------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if _active and multiplayer.is_server():
		_pending[peer_id] = 0.0


func _on_peer_disconnected(peer_id: int) -> void:
	if not _active:
		return
	_pending.erase(peer_id)
	_subscribed.erase(peer_id)
	var sid := session_of_peer(peer_id)
	if sid.is_empty():
		return
	_peer_session.erase(peer_id)
	if peer_of(sid) == peer_id:
		_session_peer.erase(sid)
		rooms.disconnect_session(sid)
		session_lost.emit(sid)


func _reject(peer_id: int, code: String) -> void:
	_to_client(peer_id, &"rpc_rejected", [code])
	var closing := _peer
	get_tree().create_timer(config.reject_flush_s).timeout.connect(func() -> void:
		if closing != null and _peer == closing and multiplayer.get_peers().has(peer_id):
			closing.disconnect_peer(peer_id))


func _to_client(peer_id: int, method: StringName, args: Array) -> void:
	if client_node == null or peer_id <= 0:
		return
	client_node.callv(&"rpc_id", [peer_id, method] + args)


func _send_error(peer_id: int, code: String) -> void:
	_to_client(peer_id, &"rpc_error", [code])


# --- messages from clients -------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func rpc_hello(proto: int, display_name: String, resume_token: String) -> void:
	if not _active:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _peer_session.has(peer_id):
		return
	if proto != config.proto_version:
		_pending.erase(peer_id)
		_reject(peer_id, "version")
		return
	var clean := _plain(display_name)
	if clean.is_empty() or clean.length() > config.name_max_len:
		_pending.erase(peer_id)
		_reject(peer_id, "bad_name")
		return
	var sid := ""
	if not resume_token.is_empty() and _resume_index.has(resume_token) and rooms.has_session(str(_resume_index[resume_token])):
		sid = str(_resume_index[resume_token])
		var old := peer_of(sid)
		if old != 0 and old != peer_id:
			_peer_session.erase(old)
			_session_peer.erase(sid)
			_peer.disconnect_peer(old)
	else:
		sid = Crypto.new().generate_random_bytes(16).hex_encode()
		var token := Crypto.new().generate_random_bytes(16).hex_encode()
		_sessions[sid] = {"name": clean, "token": token, "chat_tokens": float(config.chat_burst), "chat_stamp_ms": Time.get_ticks_msec()}
		_resume_index[token] = sid
	(_sessions[sid] as Dictionary)["name"] = clean
	_pending.erase(peer_id)
	_peer_session[peer_id] = sid
	_session_peer[sid] = peer_id
	rooms.connect_session(sid, clean)
	_to_client(peer_id, &"rpc_welcome", [sid, str((_sessions[sid] as Dictionary)["token"])])
	_to_client(peer_id, &"rpc_room_state", [_view_for(sid)])
	session_welcomed.emit(sid, clean)


@rpc("any_peer", "call_remote", "reliable")
func rpc_list_rooms() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if _sid().is_empty():
		return
	_subscribed[peer_id] = true
	_send_list(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_create_room(room_name: String, is_private: bool, options: Dictionary) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var clean := _plain(room_name)
	if clean.length() > config.name_max_len:
		_send_error(peer_id, "bad_name")
		return
	if not _payload_ok(options):
		_send_error(peer_id, "bad_options")
		return
	var code := rooms.create_room(sid, options, is_private)
	if not code.is_empty():
		_send_error(peer_id, code)
		return
	if clean.is_empty():
		clean = str((_sessions[sid] as Dictionary)["name"])
	_room_names[rooms.room_of(sid)] = clean
	_subscribed.erase(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_join_room(room_id: String) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	_after_join(rooms.join_room(sid, room_id))


@rpc("any_peer", "call_remote", "reliable")
func rpc_join_code(code: String) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	var clean := code.strip_edges().to_upper()
	_after_join(rooms.join_code(sid, clean) if clean.length() <= config.name_max_len else "no_room")


@rpc("any_peer", "call_remote", "reliable")
func rpc_leave_room() -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var code := rooms.leave_room(sid)
	if not code.is_empty():
		_send_error(peer_id, code)
		return
	_to_client(peer_id, &"rpc_room_state", [{}])
	_subscribed[peer_id] = true
	_send_list(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_slot(seat: int) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	_reply_code(rooms.set_slot(sid, seat))


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_pick(meta: Dictionary) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	if not _payload_ok(meta):
		_reply_code("bad_meta")
		return
	_reply_code(rooms.set_seat_meta(sid, meta))


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_seat_bot(seat: int, meta: Dictionary) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	if not _payload_ok(meta):
		_reply_code("bad_bot")
		return
	_reply_code(rooms.set_seat_bot(sid, seat, meta))


@rpc("any_peer", "call_remote", "reliable")
func rpc_clear_seat_bot(seat: int) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	_reply_code(rooms.clear_seat_bot(sid, seat))


@rpc("any_peer", "call_remote", "reliable")
func rpc_set_ready(on: bool) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	_reply_code(rooms.set_ready(sid, on))


@rpc("any_peer", "call_remote", "reliable")
func rpc_chat(text: String) -> void:
	var sid := _sid()
	if sid.is_empty():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var room_id := rooms.room_of(sid)
	if room_id.is_empty():
		_send_error(peer_id, "not_in_room")
		return
	var clean := _plain(text)
	if clean.is_empty():
		return
	if clean.length() > config.chat_max_len:
		_send_error(peer_id, "bad_text")
		return
	if not _take_chat_token(sid):
		_send_error(peer_id, "rate")
		return
	var seat := rooms.seat_of(sid)
	var who := str((_sessions[sid] as Dictionary)["name"])
	for member_peer in _member_peers(room_id):
		_to_client(member_peer, &"rpc_chat_line", [seat, who, clean])


# --- helpers ---------------------------------------------------------------------------

func _sid() -> String:
	if not _active:
		return ""
	return session_of_peer(multiplayer.get_remote_sender_id())


## Sends the sender an error code, if there is one ("" = ok).
func _reply_code(code: String) -> void:
	if not code.is_empty():
		_send_error(multiplayer.get_remote_sender_id(), code)


func _after_join(code: String) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if code.is_empty():
		_subscribed.erase(peer_id)
	else:
		_send_error(peer_id, code)


func _payload_ok(data: Dictionary) -> bool:
	return var_to_bytes(data).size() <= config.payload_max_bytes


## Plain text: no control characters, no BBCode brackets, trimmed.
func _plain(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 32 or c == 127:
			continue
		var ch := text[i]
		out += "(" if ch == "[" else (")" if ch == "]" else ch)
	return out.strip_edges()


func _take_chat_token(sid: String) -> bool:
	var s: Dictionary = _sessions[sid]
	var now := Time.get_ticks_msec()
	var gained := float(now - int(s["chat_stamp_ms"])) / 1000.0 * config.chat_rate_per_s
	s["chat_stamp_ms"] = now
	s["chat_tokens"] = minf(float(config.chat_burst), float(s["chat_tokens"]) + gained)
	if float(s["chat_tokens"]) < 1.0:
		return false
	s["chat_tokens"] = float(s["chat_tokens"]) - 1.0
	return true


func _member_peers(room_id: String) -> Array[int]:
	var out: Array[int] = []
	for seat: Dictionary in rooms.snapshot(room_id).get("seats", []):
		if bool(seat["free"]) or bool(seat["bot"]):
			continue
		var peer_id := peer_of(str(seat["session_id"]))
		if peer_id != 0:
			out.append(peer_id)
	return out


func _view_for(sid: String) -> Dictionary:
	var room_id := rooms.room_of(sid)
	if room_id.is_empty():
		return {}
	return _view(room_id, sid)


## What a member sees of its room. Session ids never leave the server.
func _view(room_id: String, sid: String) -> Dictionary:
	var snap := rooms.snapshot(room_id)
	if snap.is_empty():
		return {}
	var seats: Array = []
	for seat: Dictionary in snap["seats"]:
		if bool(seat["free"]):
			seats.append({"seat": seat["seat"], "free": true})
			continue
		if bool(seat["bot"]):
			seats.append({
				"seat": seat["seat"], "free": false, "bot": true, "name": "", "meta": seat["meta"],
				"ready": true, "connected": true, "host": false, "you": false,
			})
			continue
		seats.append({
			"seat": seat["seat"], "free": false, "bot": false, "name": seat["name"], "meta": seat["meta"],
			"ready": seat["ready"], "connected": seat["connected"], "host": seat["host"], "you": str(seat["session_id"]) == sid,
		})
	var view := {
		"id": room_id, "name": name_of_room(room_id), "state": snap["state"], "options": snap["options"],
		"private": snap["private"], "seats": seats, "countdown_left": snap["countdown_left"],
		"last_result": snap["last_result"],
	}
	if bool(snap["private"]):
		view["code"] = rooms.code_of(room_id)
	return view


func _push_room(room_id: String) -> void:
	for seat: Dictionary in rooms.snapshot(room_id).get("seats", []):
		if bool(seat["free"]) or bool(seat["bot"]):
			continue
		var sid := str(seat["session_id"])
		var peer_id := peer_of(sid)
		if peer_id != 0:
			_to_client(peer_id, &"rpc_room_state", [_view(room_id, sid)])


func _list_rows() -> Array:
	var rows: Array = []
	for room_id in rooms.room_ids():
		var snap := rooms.snapshot(room_id)
		if bool(snap["private"]):
			continue
		var used := 0
		for seat: Dictionary in snap["seats"]:
			if not bool(seat["free"]):
				used += 1
		if used == 0:
			continue
		rows.append({
			"id": room_id, "name": name_of_room(room_id), "seats_used": used,
			"seats": (snap["seats"] as Array).size(), "state": snap["state"], "private": false,
		})
	return rows


func _send_list(peer_id: int) -> void:
	_to_client(peer_id, &"rpc_room_list", [_list_rows()])


# --- from MpLobbyRooms -----------------------------------------------------------------

func _on_room_changed(room_id: String) -> void:
	_dirty_rooms[room_id] = true
	_list_dirty = true


func _on_room_closed(room_id: String) -> void:
	_room_names.erase(room_id)
	_dirty_rooms.erase(room_id)
	_list_dirty = true


func _on_match_assigned(_room_id: String, session_id: String, port: int, token: String) -> void:
	_to_client(peer_of(session_id), &"rpc_match_ready", [config.public_host, port, token])


func _on_room_error(room_id: String, code: String) -> void:
	for peer_id in _member_peers(room_id):
		_send_error(peer_id, code)


func _on_session_expired(session_id: String) -> void:
	var s: Dictionary = _sessions.get(session_id, {})
	if not s.is_empty():
		_resume_index.erase(s["token"])
	_sessions.erase(session_id)
	_session_peer.erase(session_id)
