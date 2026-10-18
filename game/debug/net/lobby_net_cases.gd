extends Node

## RFC-034 034d. Two processes: `--role=server` (room server, stub runner, no real dedicated) and
## `--role=clients` (four lobby stacks in one process, each with its own SceneMultiplayer).
## Scenario: two rooms, A and B, 1v1 each, in parallel; their states must be independent.
## The "dedicated" is played by the server process: it writes state.json / result.json itself
## when the clients ask through files in user://mp_lobby_net/.
## Each role closes by itself: `SERVER CASES PASS|FAIL` / `CLIENT CASES PASS|FAIL` (exit 0 / 1).

const CONFIG := preload("res://data/net/lobby_config_local.tres")
const STUB := preload("res://data/net/runner_stub.tres")
const LOBBY_SCRIPT := preload("res://addons/mp_kit/lobby/mp_lobby.gd")
const ROOT := "user://mp_lobby_net"
const CMD_RESULT_A := "user://mp_lobby_net/cmd_result_a"
const CMD_RESULT_B := "user://mp_lobby_net/cmd_result_b"
const CMD_DONE := "user://mp_lobby_net/cmd_done"
const DEFAULT_PORT := 7705
const LOCAL_HOST := "127.0.0.1"
const SERVER_TIMEOUT_S := 90.0
const CLIENT_TIMEOUT_S := 80.0
const STEP_TIMEOUT_S := 15.0
const SETTLE_S := 0.6
const HEARTBEAT_REFRESH_S := 0.5
const RESULT_WINNER_SLOT := 1
const BURST_MESSAGES := 8

var _tag: String = ""
var _fails: int = 0
var _finished: bool = false

# server
var _config: MpLobbyConfig
var _launcher: MpMatchLauncher
var _assigned: Array[Dictionary] = []
var _state_written: Dictionary = {}
var _result_written: Dictionary = {}
var _beat_accum: float = 0.0
var _max_room_count: int = 0

# clients
var _probes: Array[Probe] = []


class Probe extends RefCounted:
	var lobby: Node
	var label: String
	var updates: int = 0
	var cd_started: int = 0
	var cd_cancelled: int = 0
	var left: int = 0
	var lost: int = 0
	var matches: Array[Dictionary] = []
	var finished: Array[Dictionary] = []
	var errors: PackedStringArray = PackedStringArray()
	var chat: PackedStringArray = PackedStringArray()

	func _init(p_lobby: Node, p_label: String) -> void:
		lobby = p_lobby
		label = p_label
		var c: MpLobbyClient = p_lobby.client
		c.room_updated.connect(func(_room: Dictionary) -> void: updates += 1)
		c.countdown_started.connect(func(_s: float) -> void: cd_started += 1)
		c.countdown_cancelled.connect(func() -> void: cd_cancelled += 1)
		c.room_left.connect(func() -> void: left += 1)
		c.lobby_lost.connect(func(_r: String) -> void: lost += 1)
		c.match_ready.connect(func(h: String, p: int, t: String) -> void: matches.append({"host": h, "port": p, "token": t}))
		c.match_finished.connect(func(r: Dictionary) -> void: finished.append(r))
		c.error_received.connect(func(code: String) -> void: errors.append(code))
		c.chat_received.connect(func(_seat: int, _who: String, text: String) -> void: chat.append(text))

	func client() -> MpLobbyClient:
		return lobby.client

	func seat_names() -> PackedStringArray:
		var out := PackedStringArray()
		for seat: Dictionary in client().room.get("seats", []):
			if not bool(seat["free"]):
				out.append(str(seat["name"]))
		return out

	func my_seat_ok(seat: int) -> bool:
		return client().my_seat() == seat

	func room_state() -> int:
		return int(client().room.get("state", -1))


func _ready() -> void:
	_tag = MpBoot.user_value("role", "")
	var tree := get_tree()
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = SERVER_TIMEOUT_S if _tag == "server" else CLIENT_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("%s CASES FAIL: global timeout" % _label())
		tree.quit(1))
	tree.root.add_child.call_deferred(timer)
	timer.start.call_deferred()
	match _tag:
		"server":
			_start_server()
		"clients":
			_run_clients()
		_:
			print("LOBBY NET FAIL: --role=server|clients is required")
			tree.quit(1)


func _label() -> String:
	return "SERVER" if _tag == "server" else "CLIENT"


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_fails += 1
		print("FAIL ", what)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("%s CASES %s" % [_label(), "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_TIMEOUT_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _settle() -> void:
	await get_tree().create_timer(SETTLE_S).timeout


# =========================================================================================
# server
# =========================================================================================

func _start_server() -> void:
	MpMatchFiles.remove_dir(ROOT)
	_config = CONFIG.with_cli_overrides()
	_config.matches_root = ROOT
	_config.max_matches = 2
	if MpBoot.user_value("lobby-port", "").is_empty():
		_config.lobby_port = DEFAULT_PORT
	MpMatchFiles.ensure_dir(ROOT)
	_launcher = MpMatchLauncher.new()
	_launcher.config = _config
	_launcher.runner = STUB.duplicate() as MpProcessRunner
	_launcher.executable = "stub"
	_launcher.reap_on_ready = false
	_launcher.keep_files = true
	add_child(_launcher)
	var server: MpLobbyServer = MpLobby.server
	server.meta_validator = func(meta: Dictionary) -> bool: return meta.has("pick")
	server.options_validator = func(options: Dictionary) -> bool: return not options.has("bad")
	var err := MpLobby.start_server(_config, _launcher)
	if err != OK:
		print("SERVER CASES FAIL: lobby port %d: %s" % [_config.lobby_port, error_string(err)])
		get_tree().quit(1)
		return
	server.rooms.room_changed.connect(_on_server_room_changed)
	server.rooms.match_assigned.connect(func(room_id: String, sid: String, port: int, token: String) -> void:
		_assigned.append({"room": room_id, "sid": sid, "port": port, "token": token, "match": server.rooms.match_id_of(room_id)}))
	print("SERVER READY port=%d" % _config.lobby_port)


func _on_server_room_changed(room_id: String) -> void:
	var rooms: MpLobbyRooms = MpLobby.server.rooms
	_max_room_count = maxi(_max_room_count, rooms.room_count())
	if rooms.state_of(room_id) != MpLobbyRooms.State.LAUNCHING:
		return
	var match_id := rooms.match_id_of(room_id)
	if _state_written.has(match_id):
		return
	_state_written[match_id] = _launcher.pid_of(match_id)
	_write_state(match_id)


func _write_state(match_id: String) -> void:
	MpMatchFiles.write_json(MpMatchFiles.path_of(ROOT, match_id, MpMatchFiles.STATE), {
		"pid": int(_state_written[match_id]), "listening": true, "heartbeat_ms": MpMatchFiles.now_ms(),
	})


func _process(delta: float) -> void:
	if _tag != "server" or _finished or _launcher == null:
		return
	_beat_accum += delta
	if _beat_accum >= HEARTBEAT_REFRESH_S:
		_beat_accum = 0.0
		for match_id in _state_written.keys():
			if not _result_written.has(match_id):
				_write_state(str(match_id))
	_maybe_write_result(CMD_RESULT_A, "Sala A")
	_maybe_write_result(CMD_RESULT_B, "Sala B")
	if FileAccess.file_exists(CMD_DONE):
		_server_verdict()


func _maybe_write_result(cmd_path: String, room_name: String) -> void:
	if not FileAccess.file_exists(cmd_path):
		return
	var rooms: MpLobbyRooms = MpLobby.server.rooms
	for room_id in rooms.room_ids():
		if MpLobby.server.name_of_room(room_id) != room_name:
			continue
		var match_id := rooms.match_id_of(room_id)
		if match_id.is_empty() or _result_written.has(match_id):
			continue
		_result_written[match_id] = true
		MpMatchFiles.write_json(MpMatchFiles.path_of(ROOT, match_id, MpMatchFiles.RESULT), {
			"winner_slot": RESULT_WINNER_SLOT, "reason": "result", "room": room_name,
		})
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cmd_path))


func _server_verdict() -> void:
	if _finished:
		return
	set_process(false)
	_check(_max_room_count == 2, "server held two rooms at once")
	_check(_assigned.size() == 4, "server assigned 4 seats (got %d)" % _assigned.size())
	var by_room: Dictionary = {}
	var tokens: Dictionary = {}
	for a in _assigned:
		if not by_room.has(a["room"]):
			by_room[a["room"]] = []
		(by_room[a["room"]] as Array).append(a)
		tokens[a["token"]] = true
	_check(tokens.size() == 4, "4 different tokens")
	_check(by_room.size() == 2, "assignments come from 2 rooms")
	var ports: Dictionary = {}
	var ticket_texts: Dictionary = {}
	for room_id in by_room.keys():
		var rows: Array = by_room[room_id]
		var port := int((rows[0] as Dictionary)["port"])
		ports[port] = true
		_check(int((rows[1] as Dictionary)["port"]) == port, "room %s: both seats get the same port" % room_id)
		_check(port >= _config.match_port_min and port <= _config.match_port_max, "room %s: port %d in range" % [room_id, port])
		ticket_texts[room_id] = FileAccess.get_file_as_string(
			MpMatchFiles.path_of(ROOT, str((rows[0] as Dictionary)["match"]), MpMatchFiles.TICKET))
		_check(not (ticket_texts[room_id] as String).is_empty(), "room %s: ticket.json on disk" % room_id)
	_check(ports.size() == 2, "the two rooms got different ports")
	for room_id in by_room.keys():
		for other_id in by_room.keys():
			for a: Dictionary in by_room[room_id]:
				var text: String = ticket_texts[other_id]
				var hash_in := text.contains(MpMatchFiles.sha256(str(a["token"])))
				if room_id == other_id:
					_check(hash_in, "ticket of %s has the hash of its own seat" % room_id)
				else:
					_check(not hash_in, "ticket of %s does not accept a token of %s" % [other_id, room_id])
				if room_id == other_id:
					_check(not text.contains(str(a["token"])), "ticket of %s has no plain token" % room_id)
	_check(_launcher.active_count() == 0, "launcher has no active match at the end")
	_finish()


# =========================================================================================
# clients
# =========================================================================================

func _make_probe(node_name: String, label: String) -> Probe:
	var lobby := LOBBY_SCRIPT.new() as Node
	lobby.name = node_name
	add_child(lobby)
	return Probe.new(lobby, label)


func _run_clients() -> void:
	await get_tree().process_frame
	var port := int(MpBoot.user_value("lobby-port", str(DEFAULT_PORT)))
	var a1 := _make_probe("LobbyA1", "A1")
	var a2 := _make_probe("LobbyA2", "A2")
	var b1 := _make_probe("LobbyB1", "B1")
	var b2 := _make_probe("LobbyB2", "B2")
	_probes = [a1, a2, b1, b2]
	var names := {a1: "Ana", a2: "Aldo", b1: "Beto", b2: "Bruno"}
	for p in _probes:
		var err: Error = p.lobby.connect_to(LOCAL_HOST, port, names[p])
		_check(err == OK, "%s starts connecting" % p.label)
	_check(await _until(func() -> bool: return _probes.all(func(p: Probe) -> bool: return p.client().is_online())), "4 clients welcomed")
	_check(a1.client().session_id != b1.client().session_id, "sessions are different")

	# server-side validation
	a1.client().set_ready(true)
	_check(await _until(func() -> bool: return a1.errors.has("not_in_room")), "ready without room: not_in_room")
	a1.client().create_room("Sala X", false, {"bad": true})
	_check(await _until(func() -> bool: return a1.errors.has("bad_options")), "options validator: bad_options")

	# two rooms
	a1.client().create_room("Sala A", false, {"level": 1})
	b1.client().create_room("Sala B", false, {"level": 2})
	_check(await _until(func() -> bool: return a1.client().room.get("name", "") == "Sala A" and b1.client().room.get("name", "") == "Sala B"), "both rooms created")
	var id_a := str(a1.client().room.get("id", ""))
	var id_b := str(b1.client().room.get("id", ""))
	_check(not id_a.is_empty() and id_a != id_b, "rooms have different ids")
	a2.client().refresh_rooms()
	b2.client().refresh_rooms()
	_check(await _until(func() -> bool: return a2.client().rooms.size() == 2 and b2.client().rooms.size() == 2), "list shows both rooms")
	a2.client().join_room(id_a)
	b2.client().join_room(id_b)
	_check(await _until(func() -> bool: return a1.seat_names().size() == 2 and b1.seat_names().size() == 2 and a2.seat_names().size() == 2 and b2.seat_names().size() == 2), "each room has 2 players")
	await _settle()
	_check(a1.seat_names() == PackedStringArray(["Ana", "Aldo"]) and a2.seat_names() == PackedStringArray(["Ana", "Aldo"]), "A sees only Ana and Aldo")
	_check(b1.seat_names() == PackedStringArray(["Beto", "Bruno"]) and b2.seat_names() == PackedStringArray(["Beto", "Bruno"]), "B sees only Beto and Bruno")
	_check(a1.my_seat_ok(0) and a2.my_seat_ok(1) and b1.my_seat_ok(0) and b2.my_seat_ok(1), "creator seat 0, joiner seat 1")
	a2.client().join_room(id_b)
	_check(await _until(func() -> bool: return a2.errors.has("already_in_room")), "a seated player cannot join another room")

	# chat stays in its room, and is rate limited
	a1.client().send_chat("hola A")
	_check(await _until(func() -> bool: return a2.chat.has("hola A") and a1.chat.has("hola A")), "chat reaches the room")
	await _settle()
	_check(b1.chat.is_empty() and b2.chat.is_empty(), "chat of A does not reach B")
	for i in BURST_MESSAGES:
		b1.client().send_chat("b%d" % i)
	_check(await _until(func() -> bool: return b1.errors.has("rate")), "chat burst: rate")
	await _settle()
	_check(b2.chat.size() >= 1 and b2.chat.size() < BURST_MESSAGES, "chat burst is cut (b2 got %d of %d)" % [b2.chat.size(), BURST_MESSAGES])
	_check(a1.chat.size() == 1 and a2.chat.size() == 1, "chat of B does not reach A")

	# B validation, then A runs alone
	b1.client().set_ready(true)
	_check(await _until(func() -> bool: return b1.errors.has("bad_meta")), "ready without pick: bad_meta")
	b1.client().set_pick({"nope": 1})
	_check(await _until(func() -> bool: return b1.errors.count("bad_meta") >= 2), "pick validator: bad_meta")
	await _settle()
	var b_updates := b1.updates + b2.updates
	a1.client().set_pick({"pick": "a1"})
	a2.client().set_pick({"pick": "a2"})
	_check(await _until(func() -> bool: return _picks_of(a1) == ["a1", "a2"]), "A picks are in A")
	a1.client().set_ready(true)
	await _settle()
	_check(a1.cd_started == 0, "A with one ready: no countdown")
	a2.client().set_ready(true)
	_check(await _until(func() -> bool: return a1.cd_started == 1 and a2.cd_started == 1), "A countdown starts for both")
	_check(b1.cd_started == 0 and b2.cd_started == 0, "B has no countdown while A counts")
	_check(b1.room_state() == MpLobbyRooms.State.OPEN and b2.room_state() == MpLobbyRooms.State.OPEN, "B stays OPEN while A counts")
	_check(b1.updates + b2.updates == b_updates, "B got no update from A's picks, ready and countdown")
	_check(_picks_of(b1) == [null, null], "B picks are empty")
	_check(await _until(func() -> bool: return a1.matches.size() == 1 and a2.matches.size() == 1), "A gets match_ready")
	_check(b1.matches.is_empty() and b2.matches.is_empty(), "B gets no match_ready from A")
	_check(b1.room_state() == MpLobbyRooms.State.OPEN, "B still OPEN while A is in its match")
	_check(await _until(func() -> bool: return a1.room_state() == MpLobbyRooms.State.IN_MATCH and a2.room_state() == MpLobbyRooms.State.IN_MATCH), "A is IN_MATCH")

	# B in parallel
	b_updates = b1.updates + b2.updates
	var a_updates := a1.updates + a2.updates
	b1.client().set_pick({"pick": "b1"})
	b2.client().set_pick({"pick": "b2"})
	b1.client().set_ready(true)
	b2.client().set_ready(true)
	_check(await _until(func() -> bool: return b1.matches.size() == 1 and b2.matches.size() == 1), "B gets its own match_ready")
	_check(a1.updates + a2.updates == a_updates, "A (in match) got no update from B")
	_check(a1.cd_started == 1 and a2.cd_started == 1, "A countdown count unchanged by B")
	var tokens := {}
	var ports := {}
	for p in _probes:
		var m: Dictionary = p.matches[0]
		tokens[m["token"]] = true
		ports[m["port"]] = true
		_check(str(m["token"]).length() == 32, "%s token is 128-bit hex" % p.label)
		_check(str(m["host"]) == LOCAL_HOST, "%s host falls back to the lobby host" % p.label)
	_check(tokens.size() == 4, "4 different tokens at the clients")
	_check(ports.size() == 2, "2 different ports at the clients")
	_check(int(a1.matches[0]["port"]) == int(a2.matches[0]["port"]), "A seats share a port")
	_check(int(b1.matches[0]["port"]) == int(b2.matches[0]["port"]), "B seats share a port")
	_check(int(a1.matches[0]["port"]) != int(b1.matches[0]["port"]), "A and B ports differ")

	# A's result reaches only A
	b_updates = b1.updates + b2.updates
	_touch(CMD_RESULT_A)
	_check(await _until(func() -> bool: return a1.finished.size() == 1 and a2.finished.size() == 1), "A result reaches both A clients")
	await _settle()
	_check(b1.finished.is_empty() and b2.finished.is_empty(), "A result does not reach B")
	_check(int(a1.finished[0].get("winner_slot", 0)) == RESULT_WINNER_SLOT, "A result content")
	_check(a1.room_state() == MpLobbyRooms.State.OPEN, "A back to OPEN after the result")
	_check(b1.room_state() == MpLobbyRooms.State.IN_MATCH and b2.room_state() == MpLobbyRooms.State.IN_MATCH, "B still IN_MATCH")
	_check(b1.updates + b2.updates == b_updates, "B got no update from A's result")

	# an A client drops: B does not change
	b_updates = b1.updates + b2.updates
	a2.client().close_connection()
	_check(await _until(func() -> bool: return _seat_connected(a1, 1) == false), "A1 sees that A2 dropped")
	await _settle()
	_check(b1.updates + b2.updates == b_updates, "B did not change when an A client dropped")
	_check(b1.room_state() == MpLobbyRooms.State.IN_MATCH, "B still IN_MATCH after A drop")
	a1.client().leave_room()
	_check(await _until(func() -> bool: return a1.left == 1), "A1 left its room")
	await _settle()
	_check(b1.updates + b2.updates == b_updates, "B did not change when an A client left")

	# B's result reaches only B
	var a_finished := a1.finished.size() + a2.finished.size()
	_touch(CMD_RESULT_B)
	_check(await _until(func() -> bool: return b1.finished.size() == 1 and b2.finished.size() == 1), "B result reaches both B clients")
	await _settle()
	_check(a1.finished.size() + a2.finished.size() == a_finished, "B result does not reach A")
	_check(b1.lost == 0 and b2.lost == 0, "B clients never lost the lobby")
	_touch(CMD_DONE)
	for p in _probes:
		p.client().close_connection()
	_finish()


func _picks_of(p: Probe) -> Array:
	var out: Array = []
	for seat: Dictionary in p.client().room.get("seats", []):
		var meta: Dictionary = seat.get("meta", {})
		out.append(meta.get("pick", null))
	return out


func _seat_connected(p: Probe, seat: int) -> bool:
	for s: Dictionary in p.client().room.get("seats", []):
		if int(s["seat"]) == seat:
			return bool(s.get("connected", true))
	return true


func _touch(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("1")
		f.close()
