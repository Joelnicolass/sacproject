class_name MpLobbyRooms
extends RefCounted

## Room-server side, no network. The single owner of the state of every room: who sits where,
## who is ready, the countdown, the launch of the match process, and when a room closes.
## Seats belong to a session (`session_id`), not to a peer: a peer comes and goes, the session
## lasts `resume_grace_s` without a connection. Nothing here knows the game: a seat's `meta`
## (the pick) and the room `options` are opaque Dictionaries checked by Callables the game injects.
## Time only moves through `tick(delta)`, so tests are deterministic.
##
## Every command returns an error code String ("" = ok). Stable codes: no_session, no_room,
## already_in_room, not_in_room, rooms_cap, room_full, room_not_open, bad_options, bad_meta,
## bad_seat, seat_taken, in_match, matches_cap, spawn_failed, match_failed.

enum State { OPEN, COUNTDOWN, LAUNCHING, IN_MATCH, CLOSED }

## A room changed anything visible (state, seats, ready, meta, options, result).
signal room_changed(room_id: String)
signal room_closed(room_id: String)
signal countdown_started(room_id: String)
signal countdown_cancelled(room_id: String)
## The match listens: send each seat its connection data. `session_id` is the seat owner.
signal match_assigned(room_id: String, session_id: String, port: int, token: String)
## A launch or a match failed and the room went back to OPEN. `code`: matches_cap, spawn_failed, match_failed.
signal room_error(room_id: String, code: String)
signal session_expired(session_id: String)

class Room extends RefCounted:
	var id: String = ""
	var state: int = State.OPEN
	var options: Dictionary = {}
	var code: String = ""
	## Seat index -> session_id ("" = free).
	var seats: Array[String] = []
	var match_id: String = ""
	var match_serial: int = 0
	var port: int = 0
	var countdown_left: float = 0.0
	var empty_s: float = 0.0
	var last_result: Dictionary = {}
	## session_id -> token, only while LAUNCHING / IN_MATCH.
	var tokens: Dictionary = {}

## Needed to launch. Without one, the countdown end sends the room back to OPEN with `spawn_failed`.
var launcher: MpMatchLauncher
var config: MpLobbyConfig
## (meta: Dictionary) -> bool. Invalid Callable = accept any non-empty meta.
var meta_validator: Callable = Callable()
## (options: Dictionary) -> bool. Invalid Callable = accept any.
var options_validator: Callable = Callable()
## (seats: Array[Dictionary{slot, session_id, token, meta}], options: Dictionary) -> Dictionary (the ticket).
## Invalid Callable = `{options, seats}`. `slot` is the seat index + 1.
var ticket_builder: Callable = Callable()

var _rooms: Dictionary = {}
var _sessions: Dictionary = {}
var _match_room: Dictionary = {}
var _room_serial: int = 0


func _init(p_config: MpLobbyConfig = null, p_launcher: MpMatchLauncher = null) -> void:
	config = p_config if p_config != null else MpLobbyConfig.new()
	launcher = p_launcher
	if launcher != null:
		launcher.match_listening.connect(_on_match_listening)
		launcher.match_ended.connect(_on_match_ended)
		launcher.match_failed.connect(_on_match_failed)


# --- queries ---------------------------------------------------------------------------

func room_count() -> int:
	return _rooms.size()


func room_ids() -> PackedStringArray:
	return PackedStringArray(_rooms.keys())


func has_room(room_id: String) -> bool:
	return _rooms.has(room_id)


## CLOSED for an unknown (already closed and removed) room.
func state_of(room_id: String) -> int:
	return (_rooms[room_id] as Room).state if _rooms.has(room_id) else State.CLOSED


func room_of(session_id: String) -> String:
	return str(_sessions.get(session_id, {}).get("room_id", ""))


func has_session(session_id: String) -> bool:
	return _sessions.has(session_id)


func is_connected_session(session_id: String) -> bool:
	return bool(_sessions.get(session_id, {}).get("connected", false))


## Seat index of the session in its room, -1 if none.
func seat_of(session_id: String) -> int:
	var room := _room_for(session_id)
	return room.seats.find(session_id) if room != null else -1


func match_id_of(room_id: String) -> String:
	return (_rooms[room_id] as Room).match_id if _rooms.has(room_id) else ""


func code_of(room_id: String) -> String:
	return (_rooms[room_id] as Room).code if _rooms.has(room_id) else ""


func last_result_of(room_id: String) -> Dictionary:
	return (_rooms[room_id] as Room).last_result.duplicate(true) if _rooms.has(room_id) else {}


func countdown_left_of(room_id: String) -> float:
	return (_rooms[room_id] as Room).countdown_left if _rooms.has(room_id) else 0.0


## A copy of the public data of a room, for the list and the room view.
func snapshot(room_id: String) -> Dictionary:
	if not _rooms.has(room_id):
		return {}
	var room: Room = _rooms[room_id]
	var seats: Array = []
	for i in room.seats.size():
		var sid := room.seats[i]
		if sid.is_empty():
			seats.append({"seat": i, "free": true})
			continue
		var s: Dictionary = _sessions[sid]
		seats.append({
			"seat": i, "free": false, "session_id": sid, "name": s["name"], "meta": (s["meta"] as Dictionary).duplicate(true),
			"ready": s["ready"], "connected": s["connected"],
		})
	return {
		"id": room.id, "state": room.state, "options": room.options.duplicate(true), "private": not room.code.is_empty(),
		"seats": seats, "countdown_left": room.countdown_left, "last_result": room.last_result.duplicate(true),
	}


# --- sessions --------------------------------------------------------------------------

## A new session, or the return of a known one (same seat, same room). Always marks it connected.
func connect_session(session_id: String, display_name: String = "") -> Error:
	if session_id.is_empty():
		return ERR_INVALID_PARAMETER
	if _sessions.has(session_id):
		var s: Dictionary = _sessions[session_id]
		s["connected"] = true
		s["away_s"] = 0.0
		if not display_name.is_empty():
			s["name"] = display_name
		_touch_room(room_of(session_id))
		return OK
	_sessions[session_id] = {
		"name": display_name, "connected": true, "away_s": 0.0, "room_id": "", "meta": {}, "ready": false,
	}
	return OK


## The peer dropped. The seat stays for `resume_grace_s`. The dropped seat stops being ready.
func disconnect_session(session_id: String) -> void:
	if not _sessions.has(session_id):
		return
	var s: Dictionary = _sessions[session_id]
	s["connected"] = false
	s["away_s"] = 0.0
	var room := _room_for(session_id)
	if room != null and room.state <= State.COUNTDOWN:
		s["ready"] = false
		_cancel_countdown(room)
		room_changed.emit(room.id)


## Removes the session now (it left for good, or the server dropped it).
func drop_session(session_id: String) -> void:
	if not _sessions.has(session_id):
		return
	var room := _room_for(session_id)
	if room != null:
		_free_seat(room, session_id)
	_sessions.erase(session_id)


# --- commands --------------------------------------------------------------------------

func create_room(session_id: String, options: Dictionary = {}, is_private: bool = false) -> String:
	if not _sessions.has(session_id):
		return "no_session"
	if not room_of(session_id).is_empty():
		return "already_in_room"
	if _rooms.size() >= config.max_rooms:
		return "rooms_cap"
	if options_validator.is_valid() and not bool(options_validator.call(options)):
		return "bad_options"
	_room_serial += 1
	var room := Room.new()
	room.id = "r%d" % _room_serial
	room.options = options.duplicate(true)
	room.seats.resize(config.seats_per_room)
	room.seats.fill("")
	if is_private:
		room.code = _new_code()
	_rooms[room.id] = room
	_seat(room, session_id, 0)
	room_changed.emit(room.id)
	return ""


func join_room(session_id: String, room_id: String) -> String:
	if not _sessions.has(session_id):
		return "no_session"
	if not room_of(session_id).is_empty():
		return "already_in_room"
	if not _rooms.has(room_id):
		return "no_room"
	var room: Room = _rooms[room_id]
	if room.state != State.OPEN:
		return "room_not_open"
	var free := room.seats.find("")
	if free < 0:
		return "room_full"
	_seat(room, session_id, free)
	room_changed.emit(room.id)
	return ""


## Join by private code. "no_room" if no room has it.
func join_code(session_id: String, code: String) -> String:
	for room_id in _rooms.keys():
		var room: Room = _rooms[room_id]
		if not room.code.is_empty() and room.code == code:
			return join_room(session_id, room_id)
	return "no_room"


func leave_room(session_id: String) -> String:
	var room := _room_for(session_id)
	if room == null:
		return "not_in_room" if _sessions.has(session_id) else "no_session"
	if room.state >= State.LAUNCHING:
		return "in_match"
	_free_seat(room, session_id)
	return ""


## The seat's pick. Changing it clears that seat's ready (and cancels the countdown).
func set_seat_meta(session_id: String, meta: Dictionary) -> String:
	var room := _room_for(session_id)
	if room == null:
		return "not_in_room" if _sessions.has(session_id) else "no_session"
	if room.state > State.COUNTDOWN:
		return "room_not_open"
	if not _meta_ok(meta):
		return "bad_meta"
	var s: Dictionary = _sessions[session_id]
	s["meta"] = meta.duplicate(true)
	s["ready"] = false
	_cancel_countdown(room)
	room_changed.emit(room.id)
	return ""


## Moves the session to a free seat. Clears its ready (and cancels the countdown).
func set_slot(session_id: String, seat: int) -> String:
	var room := _room_for(session_id)
	if room == null:
		return "not_in_room" if _sessions.has(session_id) else "no_session"
	if room.state > State.COUNTDOWN:
		return "room_not_open"
	if seat < 0 or seat >= room.seats.size():
		return "bad_seat"
	if room.seats[seat] != "" and room.seats[seat] != session_id:
		return "seat_taken"
	var old := room.seats.find(session_id)
	if old != seat:
		room.seats[old] = ""
		room.seats[seat] = session_id
	(_sessions[session_id] as Dictionary)["ready"] = false
	_cancel_countdown(room)
	room_changed.emit(room.id)
	return ""


## Ready needs a valid pick. A full room where everyone is ready and connected starts the countdown.
func set_ready(session_id: String, on: bool) -> String:
	var room := _room_for(session_id)
	if room == null:
		return "not_in_room" if _sessions.has(session_id) else "no_session"
	if room.state > State.COUNTDOWN:
		return "room_not_open"
	var s: Dictionary = _sessions[session_id]
	if on and not _meta_ok(s["meta"]):
		return "bad_meta"
	s["ready"] = on
	if not on:
		_cancel_countdown(room)
	elif room.state == State.OPEN and _all_ready(room):
		room.state = State.COUNTDOWN
		room.countdown_left = config.countdown_s
		countdown_started.emit(room.id)
	room_changed.emit(room.id)
	return ""


# --- time ------------------------------------------------------------------------------

func tick(delta: float) -> void:
	for room_id in _rooms.keys():
		if not _rooms.has(room_id):
			continue
		var room: Room = _rooms[room_id]
		if room.state == State.COUNTDOWN:
			room.countdown_left = maxf(0.0, room.countdown_left - delta)
			if room.countdown_left <= 0.0:
				_launch(room)
		_tick_empty(room, delta)
	for session_id in _sessions.keys():
		_tick_session(str(session_id), delta)


# --- internals -------------------------------------------------------------------------

func _tick_empty(room: Room, delta: float) -> void:
	if not _rooms.has(room.id):
		return
	if _seated_count(room) > 0:
		room.empty_s = 0.0
		return
	room.empty_s += delta
	if room.empty_s >= config.empty_room_close_s:
		_close(room)


func _tick_session(session_id: String, delta: float) -> void:
	var s: Dictionary = _sessions.get(session_id, {})
	if s.is_empty() or bool(s["connected"]):
		return
	var room := _room_for(session_id)
	# In a launching / running match the player is away on purpose: the grace starts at the result.
	if room != null and room.state >= State.LAUNCHING:
		return
	s["away_s"] = float(s["away_s"]) + delta
	if float(s["away_s"]) >= config.resume_grace_s:
		drop_session(session_id)
		session_expired.emit(session_id)


func _launch(room: Room) -> void:
	room.state = State.LAUNCHING
	room.match_serial += 1
	room.match_id = "%s_m%d" % [room.id, room.match_serial]
	var rows: Array[Dictionary] = []
	room.tokens.clear()
	for i in room.seats.size():
		var sid := room.seats[i]
		var token := MpMatchFiles.new_token()
		room.tokens[sid] = token
		rows.append({"slot": i + 1, "session_id": sid, "token": token, "meta": (_sessions[sid]["meta"] as Dictionary).duplicate(true)})
	var ticket: Dictionary
	if ticket_builder.is_valid():
		ticket = ticket_builder.call(rows, room.options.duplicate(true))
	else:
		ticket = {"options": room.options.duplicate(true), "seats": rows}
	# The ticket carries seats keyed by slot/token/meta; the session id stays in the server.
	var seats: Array = []
	for row in ticket.get("seats", []):
		var copy: Dictionary = (row as Dictionary).duplicate()
		copy.erase("session_id")
		seats.append(copy)
	ticket["seats"] = seats
	var err: Error = ERR_UNCONFIGURED if launcher == null else launcher.launch(room.match_id, ticket)
	if err != OK:
		_back_to_open(room, "matches_cap" if err == ERR_BUSY else "spawn_failed")
		return
	_match_room[room.match_id] = room.id
	room_changed.emit(room.id)


func _on_match_listening(match_id: String, port: int) -> void:
	var room := _room_of_match(match_id)
	if room == null or room.state != State.LAUNCHING:
		return
	room.state = State.IN_MATCH
	room.port = port
	room_changed.emit(room.id)
	for sid in room.seats:
		match_assigned.emit(room.id, sid, port, str(room.tokens.get(sid, "")))


func _on_match_ended(match_id: String, result: Dictionary) -> void:
	var room := _room_of_match(match_id)
	if room == null:
		return
	_match_room.erase(match_id)
	room.last_result = result.duplicate(true)
	_reset_after_match(room)
	room_changed.emit(room.id)


func _on_match_failed(match_id: String, reason: String) -> void:
	var room := _room_of_match(match_id)
	if room == null:
		return
	_match_room.erase(match_id)
	var was_launching := room.state == State.LAUNCHING
	room.last_result = {} if was_launching else {"reason": reason}
	_reset_after_match(room)
	room_error.emit(room.id, "spawn_failed" if was_launching else "match_failed")
	room_changed.emit(room.id)


func _back_to_open(room: Room, code: String) -> void:
	_reset_after_match(room)
	room_error.emit(room.id, code)
	room_changed.emit(room.id)


## Ready is cleared, tokens forgotten, and the away clock of the seats restarts.
func _reset_after_match(room: Room) -> void:
	room.state = State.OPEN
	room.tokens.clear()
	room.match_id = ""
	room.port = 0
	room.countdown_left = 0.0
	for sid in room.seats:
		if sid.is_empty():
			continue
		var s: Dictionary = _sessions[sid]
		s["ready"] = false
		s["away_s"] = 0.0


func _close(room: Room) -> void:
	room.state = State.CLOSED
	if not room.match_id.is_empty():
		_match_room.erase(room.match_id)
		if launcher != null:
			launcher.abort(room.match_id, "room_closed")
	for sid in room.seats:
		if not sid.is_empty():
			(_sessions[sid] as Dictionary)["room_id"] = ""
	_rooms.erase(room.id)
	room_closed.emit(room.id)


func _cancel_countdown(room: Room) -> void:
	if room.state == State.COUNTDOWN:
		room.state = State.OPEN
		room.countdown_left = 0.0
		countdown_cancelled.emit(room.id)


func _all_ready(room: Room) -> bool:
	for sid in room.seats:
		if sid.is_empty():
			return false
		var s: Dictionary = _sessions[sid]
		if not bool(s["ready"]) or not bool(s["connected"]):
			return false
	return true


func _seated_count(room: Room) -> int:
	var n := 0
	for sid in room.seats:
		if not sid.is_empty():
			n += 1
	return n


func _seat(room: Room, session_id: String, seat: int) -> void:
	room.seats[seat] = session_id
	room.empty_s = 0.0
	var s: Dictionary = _sessions[session_id]
	s["room_id"] = room.id
	s["ready"] = false
	s["meta"] = {}


func _free_seat(room: Room, session_id: String) -> void:
	var i := room.seats.find(session_id)
	if i >= 0:
		room.seats[i] = ""
	var s: Dictionary = _sessions.get(session_id, {})
	if not s.is_empty():
		s["room_id"] = ""
		s["ready"] = false
		s["meta"] = {}
	_cancel_countdown(room)
	room_changed.emit(room.id)


func _touch_room(room_id: String) -> void:
	if _rooms.has(room_id):
		(_rooms[room_id] as Room).empty_s = 0.0
		room_changed.emit(room_id)


func _meta_ok(meta: Dictionary) -> bool:
	if meta.is_empty():
		return false
	return not meta_validator.is_valid() or bool(meta_validator.call(meta))


func _room_for(session_id: String) -> Room:
	var room_id := room_of(session_id)
	return _rooms[room_id] as Room if _rooms.has(room_id) else null


func _room_of_match(match_id: String) -> Room:
	var room_id := str(_match_room.get(match_id, ""))
	return _rooms[room_id] as Room if _rooms.has(room_id) else null


func _new_code() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var taken := {}
	for room in _rooms.values():
		taken[(room as Room).code] = true
	var code := ""
	while code.is_empty() or taken.has(code):
		code = ""
		for i in 5:
			code += ALPHABET[randi() % ALPHABET.length()]
	return code
