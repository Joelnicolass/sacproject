extends Node

## Headless, no network, no processes: every transition of MpLobbyRooms with a stub runner (RFC-034 034c).
## Closes by itself: prints one PASS / FAIL line per check and `LOBBY CASES PASS` (exit 0)
## or `LOBBY CASES FAIL: n` (exit 1).

const CONFIG := preload("res://data/net/lobby_config_local.tres")
const STUB := preload("res://data/net/runner_stub.tres")
const ROOT := "user://mp_lobby_cases"
const TOTAL_TIMEOUT_S := 30.0

var _fails: int = 0
var _launcher: MpMatchLauncher
var _rooms: MpLobbyRooms
var _runner: MpProcessRunnerStub
var _errors: PackedStringArray = PackedStringArray()
var _assigned: Array[Dictionary] = []
var _closed: PackedStringArray = PackedStringArray()
var _expired: PackedStringArray = PackedStringArray()
var _cancelled: PackedStringArray = PackedStringArray()
var _started: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var watchdog := get_tree().create_timer(TOTAL_TIMEOUT_S)
	watchdog.timeout.connect(func() -> void:
		print("LOBBY CASES FAIL: global timeout")
		get_tree().quit(1))
	_case_initial()
	_case_create_join_errors()
	_case_ready_and_countdown()
	_case_launch_and_result()
	_case_caps_and_ports()
	_case_spawn_failures()
	_case_heartbeat_kill()
	_case_resume()
	_case_empty_close()
	_case_in_match_rules()
	_case_private_code()
	_case_seats_by_mode()
	_case_host_and_bots()
	_case_bots_in_ticket()
	_case_sacrifice_glue()
	_cleanup()
	if _fails == 0:
		print("LOBBY CASES PASS")
	else:
		print("LOBBY CASES FAIL: %d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


# --- cases -----------------------------------------------------------------------------

func _case_initial() -> void:
	_fresh()
	_check(_rooms.room_count() == 0, "initial: 0 rooms")
	_check(_launcher.active_count() == 0, "initial: 0 processes")
	_check(_rooms.state_of("nope") == MpLobbyRooms.State.CLOSED, "unknown room reads as CLOSED")


func _case_create_join_errors() -> void:
	_fresh({"max_rooms": 2})
	_check(_rooms.create_room("a") == "no_session", "create without session: no_session")
	_rooms.connect_session("a", "Ana")
	_rooms.connect_session("b", "Beto")
	_rooms.connect_session("c", "Cris")
	_check(_rooms.create_room("a", {"bad": true}) == "bad_options", "options validator rejects: bad_options")
	_check(_rooms.create_room("a", {"level": 1}) == "", "create ok")
	var r1 := _rooms.room_of("a")
	_check(_rooms.state_of(r1) == MpLobbyRooms.State.OPEN, "new room is OPEN")
	_check(_rooms.seat_of("a") == 0, "creator takes seat 0")
	_check(_rooms.create_room("a") == "already_in_room", "create while seated: already_in_room")
	_check(_rooms.join_room("b", "nope") == "no_room", "join unknown: no_room")
	_check(_rooms.join_room("zz", r1) == "no_session", "join without session: no_session")
	_check(_rooms.join_room("b", r1) == "", "join ok")
	_check(_rooms.seat_of("b") == 1, "joiner takes the free seat")
	_check(_rooms.join_room("c", r1) == "room_full", "third player: room_full")
	_check(_rooms.join_room("b", r1) == "already_in_room", "join twice: already_in_room")
	_check(_rooms.create_room("c") == "", "second room ok")
	_rooms.connect_session("d", "Dani")
	_check(_rooms.create_room("d") == "rooms_cap", "max_rooms reached: rooms_cap")
	_check(_rooms.leave_room("zz") == "no_session", "leave without session: no_session")
	_check(_rooms.leave_room("d") == "not_in_room", "leave without room: not_in_room")
	_check(_rooms.leave_room("b") == "", "leave ok")
	_check(_rooms.seat_of("b") == -1 and _rooms.room_of("b") == "", "leaver has no seat")
	_check(_rooms.set_ready("d", true) == "not_in_room", "ready without room: not_in_room")
	_check(_rooms.set_seat_meta("d", {"x": 1}) == "not_in_room", "meta without room: not_in_room")
	_check(_rooms.set_slot("d", 0) == "not_in_room", "slot without room: not_in_room")
	_check(_rooms.snapshot(r1)["seats"].size() == 2, "snapshot has seats_per_room seats")


func _case_ready_and_countdown() -> void:
	_fresh()
	var r := _full_room()
	_check(_rooms.set_ready("a", true) == "bad_meta", "ready without pick: bad_meta")
	_check(_rooms.set_seat_meta("a", {"pick": "bad"}) == "bad_meta", "meta validator rejects: bad_meta")
	_check(_rooms.set_seat_meta("a", {}) == "bad_meta", "empty meta: bad_meta")
	_check(_rooms.set_seat_meta("a", {"pick": "x"}) == "", "meta ok")
	_check(_rooms.set_seat_meta("b", {"pick": "y"}) == "", "meta ok (b)")
	_check(_rooms.set_ready("a", true) == "", "ready a")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "one ready: still OPEN")
	_check(_rooms.set_ready("b", true) == "", "ready b")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "full and all ready: COUNTDOWN")
	_check(_started.size() == 1 and _started[0] == r, "countdown_started emitted")
	_check(is_equal_approx(_rooms.countdown_left_of(r), CONFIG.countdown_s), "countdown starts at countdown_s")
	_check(_rooms.join_room("c", r) == "room_not_open", "join during COUNTDOWN: room_not_open")
	_rooms.tick(0.4)
	_check(is_equal_approx(_rooms.countdown_left_of(r), CONFIG.countdown_s - 0.4), "tick lowers the countdown")
	_check(_rooms.set_ready("b", false) == "", "unready")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "unready in COUNTDOWN: OPEN")
	_check(_cancelled.size() == 1, "countdown_cancelled emitted")
	_rooms.set_ready("b", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "ready again: COUNTDOWN again")
	_check(_rooms.set_seat_meta("a", {"pick": "z"}) == "", "pick change in COUNTDOWN")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "pick change cancels: OPEN")
	_check(not bool(_rooms.snapshot(r)["seats"][0]["ready"]), "pick change clears that seat's ready")
	_rooms.set_ready("a", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "ready again after pick: COUNTDOWN")
	_rooms.disconnect_session("a")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "peer drops in COUNTDOWN: OPEN")
	_check(_rooms.seat_of("a") == 0, "dropped seat is kept")
	_rooms.connect_session("a")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN and not bool(_rooms.snapshot(r)["seats"][0]["ready"]), "returning seat is not ready")
	_rooms.set_ready("a", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "ready after return: COUNTDOWN")
	_check(_rooms.leave_room("b") == "", "leave in COUNTDOWN")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "leave in COUNTDOWN: OPEN")
	_check(_rooms.join_room("c", r) == "", "freed seat can be taken")
	_check(_rooms.set_slot("a", 5) == "bad_seat", "slot out of range: bad_seat")
	_check(_rooms.set_slot("a", 1) == "seat_taken", "slot taken: seat_taken")
	_rooms.leave_room("c")
	_check(_rooms.set_slot("a", 1) == "", "move to a free seat")
	_check(_rooms.seat_of("a") == 1, "seat changed")


func _case_launch_and_result() -> void:
	_fresh()
	var r := _full_room(true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "setup: COUNTDOWN")
	_rooms.tick(CONFIG.countdown_s - 0.1)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "before the end: COUNTDOWN")
	_rooms.tick(0.2)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.LAUNCHING, "end of countdown: LAUNCHING")
	_check(_launcher.active_count() == 1 and _runner.spawned.size() == 1, "launcher started one process")
	_check(_rooms.join_room("c", r) == "room_not_open", "join during LAUNCHING: room_not_open")
	_check(_rooms.set_ready("a", false) == "room_not_open", "ready change during LAUNCHING: room_not_open")
	var mid := _rooms.match_id_of(r)
	_check(not mid.is_empty() and _launcher.pid_of(mid) > 0, "room has a match id")
	_write_state(mid, true, MpMatchFiles.now_ms())
	_launcher.poll()
	_check(_rooms.state_of(r) == MpLobbyRooms.State.IN_MATCH, "match listening: IN_MATCH")
	_check(_assigned.size() == 2, "match_assigned for both seats")
	var port: int = _assigned[0]["port"] if not _assigned.is_empty() else 0
	_check(port >= CONFIG.match_port_min and port <= CONFIG.match_port_max, "port is in range")
	var t0 := str(_assigned[0]["token"]) if _assigned.size() == 2 else ""
	var t1 := str(_assigned[1]["token"]) if _assigned.size() == 2 else ""
	_check(t0 != t1 and t0.length() == 32, "one token per seat")
	_check(_assigned.size() == 2 and _assigned[0]["session_id"] == "a" and _assigned[1]["session_id"] == "b", "assignments name the session")
	var ticket := MpMatchFiles.read_json(MpMatchFiles.path_of(ROOT, mid, MpMatchFiles.TICKET))
	var seats: Array = ticket.get("seats", [])
	var seat0: Dictionary = seats[0] if seats.size() == 2 else {}
	_check(int(seat0.get("slot", 0)) == 1 and seat0.has("token_sha256") and not seat0.has("token") and not seat0.has("session_id"), "ticket: slot 1, hash only, no session id")
	_check(seats.size() == 2 and str(seats[1]["meta"].get("pick", "")) == "y", "ticket carries the pick as is")
	_check(int(ticket.get("options", {}).get("level", 0)) == 1, "ticket carries the options")
	_finish_match(mid, {"winner_slot": 1})
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "result: OPEN")
	_check(int(_rooms.last_result_of(r).get("winner_slot", 0)) == 1, "result stays in the room")
	_check(not bool(_rooms.snapshot(r)["seats"][0]["ready"]) and not bool(_rooms.snapshot(r)["seats"][1]["ready"]), "result clears ready")
	_check(_rooms.seat_of("a") == 0 and _rooms.seat_of("b") == 1, "seats survive the match")
	_check(_launcher.active_count() == 0, "no process left")
	_rooms.set_ready("a", true)
	_rooms.set_ready("b", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "second round: COUNTDOWN")
	_check(_rooms.match_id_of(r) == "", "match id cleared between rounds")


func _case_caps_and_ports() -> void:
	_fresh({"max_matches": 1})
	var r1 := _full_room(true, "a", "b")
	var r2 := _full_room(true, "c", "d")
	_rooms.tick(CONFIG.countdown_s + 0.1)
	_check(_rooms.state_of(r1) == MpLobbyRooms.State.LAUNCHING, "first room launches")
	_check(_rooms.state_of(r2) == MpLobbyRooms.State.OPEN, "max_matches: second room back to OPEN")
	_check(_errors.has("%s:matches_cap" % r2), "max_matches: room_error matches_cap")
	_check(_launcher.active_count() == 1, "only one process")
	_launcher.config.max_matches = 2
	_rooms.set_ready("c", true)
	_rooms.set_ready("d", true)
	_rooms.tick(CONFIG.countdown_s + 0.1)
	_check(_rooms.state_of(r2) == MpLobbyRooms.State.LAUNCHING, "after raising the cap: second room launches")
	var p1 := _launcher.port_of(_rooms.match_id_of(r1))
	var p2 := _launcher.port_of(_rooms.match_id_of(r2))
	_check(p1 > 0 and p2 > 0 and p1 != p2, "ports are assigned and do not repeat")
	_launcher.abort(_rooms.match_id_of(r1), "test")
	_launcher.abort(_rooms.match_id_of(r2), "test")
	_check(_runner.killed.size() == 2, "aborted matches were killed")


func _case_spawn_failures() -> void:
	_fresh()
	var r := _full_room(true)
	_runner.spawn_fails = true
	_rooms.tick(CONFIG.countdown_s + 0.1)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "spawn fails: OPEN")
	_check(_errors.has("%s:spawn_failed" % r), "spawn fails: spawn_failed")
	_check(_rooms.match_id_of(r) == "" and _launcher.active_count() == 0, "spawn fails: nothing left")
	_check(not bool(_rooms.snapshot(r)["seats"][0]["ready"]), "spawn fails: ready cleared")
	_runner.spawn_fails = false
	_errors.clear()
	_rooms.set_ready("a", true)
	_rooms.set_ready("b", true)
	_rooms.tick(CONFIG.countdown_s + 0.1)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.LAUNCHING, "retry launches")
	_launcher.config.spawn_timeout_s = 0.0
	OS.delay_msec(5)
	_launcher.poll()
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "spawn timeout: OPEN")
	_check(_errors.has("%s:spawn_failed" % r), "spawn timeout: spawn_failed")
	_check(_runner.killed.size() == 1, "spawn timeout: process killed")
	var lonely := MpLobbyRooms.new(_rooms_config())
	lonely.meta_validator = _meta_ok
	lonely.connect_session("a")
	lonely.connect_session("b")
	var lr := _seat_two(lonely, "a", "b")
	lonely.tick(CONFIG.countdown_s + 0.1)
	_check(lonely.state_of(lr) == MpLobbyRooms.State.OPEN, "no launcher: back to OPEN")


func _case_heartbeat_kill() -> void:
	_fresh()
	var r := _full_room(true)
	_rooms.tick(CONFIG.countdown_s + 0.1)
	var mid := _rooms.match_id_of(r)
	var pid := _launcher.pid_of(mid)
	_write_state(mid, true, MpMatchFiles.now_ms())
	_launcher.poll()
	_check(_rooms.state_of(r) == MpLobbyRooms.State.IN_MATCH, "heartbeat: IN_MATCH while fresh")
	_write_state(mid, true, MpMatchFiles.now_ms() - int((CONFIG.heartbeat_stale_s + 5.0) * 1000.0))
	_launcher.poll()
	_check(_runner.killed.has(pid), "old heartbeat: process killed")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "old heartbeat: room back to OPEN")
	_check(_errors.has("%s:match_failed" % r), "old heartbeat: match_failed")
	_check(str(_rooms.last_result_of(r).get("reason", "")) == "heartbeat_stale", "old heartbeat: reason kept")


func _case_resume() -> void:
	_fresh()
	var r := _full_room()
	_rooms.disconnect_session("b")
	_rooms.tick(CONFIG.resume_grace_s - 1.0)
	_check(_rooms.seat_of("b") == 1, "inside the grace: seat kept")
	_rooms.connect_session("b")
	_check(_rooms.seat_of("b") == 1 and _rooms.room_of("b") == r, "returns inside resume_grace_s: same seat")
	_rooms.tick(CONFIG.resume_grace_s + 1.0)
	_check(_rooms.seat_of("b") == 1, "connected session never expires")
	_rooms.disconnect_session("b")
	_rooms.tick(CONFIG.resume_grace_s - 1.0)
	_rooms.connect_session("b")
	_rooms.disconnect_session("b")
	_rooms.tick(CONFIG.resume_grace_s - 1.0)
	_check(_rooms.seat_of("b") == 1, "grace restarts at each drop")
	_rooms.tick(2.0)
	_check(not _rooms.has_session("b") and _expired.size() == 1 and _expired[0] == "b", "past the grace: session expires")
	_check(_rooms.seat_of("b") == -1 and _rooms.join_room("c", r) == "", "expired seat is free")
	_rooms.connect_session("b")
	_check(_rooms.seat_of("b") == -1, "late return starts a fresh session")


func _case_empty_close() -> void:
	_fresh()
	var r := _full_room()
	_rooms.leave_room("a")
	_rooms.leave_room("b")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "empty room is not closed at once")
	_rooms.tick(CONFIG.empty_room_close_s - 0.5)
	_rooms.join_room("a", r)
	_rooms.tick(CONFIG.empty_room_close_s)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "someone came in: the timer restarts")
	_rooms.leave_room("a")
	_rooms.tick(CONFIG.empty_room_close_s - 0.5)
	_check(_rooms.has_room(r), "just before the timer: still there")
	_rooms.tick(1.0)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.CLOSED and not _rooms.has_room(r), "empty for empty_room_close_s: CLOSED")
	_check(_closed.size() == 1 and _closed[0] == r, "room_closed emitted")
	_check(_rooms.room_count() == 0, "closed room removed")
	_check(_rooms.create_room("a") == "", "a closed room frees the cap")
	var r2 := _rooms.room_of("a")
	_rooms.disconnect_session("a")
	_rooms.tick(CONFIG.resume_grace_s + 0.1)
	_check(_rooms.has_room(r2) and _rooms.seat_of("a") == -1, "expiry empties the room")
	_rooms.tick(CONFIG.empty_room_close_s + 0.1)
	_check(_rooms.state_of(r2) == MpLobbyRooms.State.CLOSED, "abandoned room: CLOSED")


func _case_in_match_rules() -> void:
	_fresh()
	var r := _full_room(true)
	_rooms.tick(CONFIG.countdown_s + 0.1)
	var mid := _rooms.match_id_of(r)
	_check(_rooms.leave_room("a") == "in_match", "leave during LAUNCHING: in_match")
	_write_state(mid, true, MpMatchFiles.now_ms())
	_launcher.poll()
	_check(_rooms.leave_room("a") == "in_match", "leave during IN_MATCH: in_match")
	_check(_rooms.set_seat_meta("a", {"pick": "z"}) == "room_not_open", "pick during IN_MATCH: room_not_open")
	_check(_rooms.set_slot("a", 1) == "room_not_open", "slot during IN_MATCH: room_not_open")
	_rooms.disconnect_session("a")
	_rooms.disconnect_session("b")
	_rooms.tick(CONFIG.resume_grace_s * 3.0)
	_check(_rooms.seat_of("a") == 0 and _rooms.seat_of("b") == 1, "away seats do not expire during the match")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.IN_MATCH and _rooms.has_room(r), "a running match keeps its room open")
	_finish_match(mid, {"winner_slot": 2})
	_rooms.tick(CONFIG.resume_grace_s - 1.0)
	_rooms.connect_session("a")
	_check(_rooms.seat_of("a") == 0 and _rooms.state_of(r) == MpLobbyRooms.State.OPEN, "back after the match: same seat, OPEN")
	_rooms.tick(2.0)
	_check(_rooms.seat_of("b") == -1, "the grace counted from the result: absent seat freed")


func _case_private_code() -> void:
	_fresh()
	_rooms.connect_session("a")
	_rooms.connect_session("b")
	_check(_rooms.create_room("a", {"level": 1}, true) == "", "private room created")
	var r := _rooms.room_of("a")
	var code := _rooms.code_of(r)
	_check(code.length() == 5, "private room has a code")
	_check(bool(_rooms.snapshot(r)["private"]), "snapshot marks it private")
	_check(_rooms.join_code("b", "WRONG") == "no_room", "wrong code: no_room")
	_check(_rooms.join_code("b", code) == "", "right code joins")
	_check(_rooms.room_of("b") == r, "joined the right room")


## RFC-049 049f: the seats of a room come from the options (`seat_count_for`); the config says 2 and caps at `max_seats_per_room`.
func _case_seats_by_mode() -> void:
	_check(CONFIG.proto_version == 2, "proto_version is 2")
	_fresh({"max_seats_per_room": 6})
	_rooms.seat_count_for = func(o: Dictionary) -> int: return int(o.get("seats", 0))
	_rooms.connect_session("a", "Ana")
	_rooms.connect_session("b", "Beto")
	_rooms.connect_session("c", "Cris")
	_check(_rooms.create_room("a", {"seats": 4}) == "", "create a 4-seat room")
	var r4 := _rooms.room_of("a")
	_check(_rooms.snapshot(r4)["seats"].size() == 4, "the room has 4 seats (the options say so)")
	_check(_rooms.create_room("b", {"seats": 0}) == "bad_options", "0 seats: bad_options")
	_check(_rooms.create_room("b", {"seats": 20}) == "", "20 seats asked")
	_check(_rooms.snapshot(_rooms.room_of("b"))["seats"].size() == 6, "the cap max_seats_per_room wins (6)")
	_rooms.seat_count_for = Callable()
	_check(_rooms.create_room("c", {}) == "", "no callable: create ok")
	_check(_rooms.snapshot(_rooms.room_of("c"))["seats"].size() == 2, "no callable: seats_per_room (2)")


## RFC-049 049f: the creator is the host and fills free seats with bots; a bot is occupied and always ready.
func _case_host_and_bots() -> void:
	_fresh()
	_rooms.seat_count_for = func(_o: Dictionary) -> int: return 4
	_rooms.bot_validator = func(m: Dictionary) -> bool: return str(m.get("tag", "")) != "bad"
	for sid in ["a", "b", "c", "d"]:
		_rooms.connect_session(sid, sid)
	_rooms.create_room("a", {"level": 1})
	var r := _rooms.room_of("a")
	_check(_rooms.host_of(r) == "a", "the creator is the host")
	_rooms.join_room("b", r)
	_check(_rooms.set_seat_bot("b", 2, {"tag": "x"}) == "not_host", "a guest cannot put a bot: not_host")
	_check(_rooms.clear_seat_bot("b", 2) == "not_host", "a guest cannot take a bot: not_host")
	_check(_rooms.set_seat_bot("zz", 2) == "no_session", "bot without session: no_session")
	_check(_rooms.set_seat_bot("d", 2) == "not_in_room", "bot without room: not_in_room")
	_check(_rooms.set_seat_bot("a", 9, {"tag": "x"}) == "bad_seat", "bot out of range: bad_seat")
	_check(_rooms.set_seat_bot("a", 1, {"tag": "x"}) == "seat_taken", "bot on a human seat: seat_taken")
	_check(_rooms.set_seat_bot("a", 2, {"tag": "bad"}) == "bad_bot", "bot validator rejects: bad_bot")
	_check(_rooms.set_seat_bot("a", 2, {"tag": "x"}) == "", "host puts a bot in seat 2")
	_check(_rooms.set_seat_bot("a", 3, {"tag": "y"}) == "", "host puts a bot in seat 3")
	var seats: Array = _rooms.snapshot(r)["seats"]
	_check(bool(seats[2]["bot"]) and not bool(seats[2]["free"]) and bool(seats[2]["ready"]) and str(seats[3]["meta"]["tag"]) == "y", "a bot seat is occupied, ready and keeps its meta")
	_check(bool(seats[0]["host"]) and not bool(seats[1]["host"]), "the snapshot marks the host")
	_check(_rooms.join_room("c", r) == "room_full", "humans + bots fill the room: room_full")
	_check(_rooms.set_slot("b", 2) == "seat_taken", "a human cannot sit on a bot seat: seat_taken")
	_check(_rooms.clear_seat_bot("a", 0) == "bad_seat", "taking a bot from a human seat: bad_seat")
	_rooms.set_seat_meta("a", {"pick": "x"})
	_rooms.set_seat_meta("b", {"pick": "y"})
	_rooms.set_ready("a", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "one human ready, the other not: OPEN")
	_rooms.set_ready("b", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "2 humans ready + 2 bots: COUNTDOWN")
	_check(_rooms.clear_seat_bot("a", 3) == "", "the host takes a bot out during the COUNTDOWN")
	_check(_rooms.state_of(r) == MpLobbyRooms.State.OPEN, "changing a bot cancels the countdown")
	_check(bool(_rooms.snapshot(r)["seats"][3]["free"]), "the freed seat is free")
	_check(_rooms.join_room("c", r) == "", "a human takes the freed seat")
	_check(_rooms.seat_of("c") == 3, "the joiner is in seat 3")
	_rooms.leave_room("c")
	_rooms.set_seat_bot("a", 3, {"tag": "y"})
	# the host leaves: the other human leads, the bots stay
	_check(_rooms.leave_room("a") == "", "the host leaves")
	_check(_rooms.host_of(r) == "b", "the host passes to the other human")
	_check(_rooms.set_seat_bot("b", 0, {"tag": "z"}) == "", "the new host puts a bot")
	_check(_rooms.set_seat_bot("a", 1, {"tag": "x"}) == "not_in_room", "the old host is out of the room")
	_rooms.leave_room("b")
	_check(_rooms.host_of(r) == "" and _rooms.snapshot(r)["seats"].all(func(x: Dictionary) -> bool: return bool(x["free"])), "nobody left: no host and no bots")
	# a host that expires (away past the grace) passes the lead too
	_rooms.join_room("c", r)
	_rooms.join_room("d", r)
	_check(_rooms.host_of(r) == "c", "the first seated human is the host of an empty room")
	_rooms.disconnect_session("c")
	_rooms.tick(CONFIG.resume_grace_s + 1.0)
	_check(_rooms.host_of(r) == "d", "the host expires: the lead goes to the other human")


## RFC-049 049f: bot rows go to the ticket without a token; the agent never admits them.
func _case_bots_in_ticket() -> void:
	_fresh()
	_rooms.seat_count_for = func(_o: Dictionary) -> int: return 4
	for sid in ["a", "b"]:
		_rooms.connect_session(sid, sid)
	_rooms.create_room("a", {"level": 1})
	var r := _rooms.room_of("a")
	_rooms.join_room("b", r)
	_rooms.set_seat_bot("a", 2, {"tag": "p"})
	_rooms.set_seat_bot("a", 3, {"tag": "q"})
	_rooms.set_seat_meta("a", {"pick": "x"})
	_rooms.set_seat_meta("b", {"pick": "y"})
	_rooms.set_ready("a", true)
	_rooms.set_ready("b", true)
	_rooms.tick(CONFIG.countdown_s + 0.1)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.LAUNCHING, "2 humans + 2 bots launch")
	var mid := _rooms.match_id_of(r)
	_write_state(mid, true, MpMatchFiles.now_ms())
	_launcher.poll()
	_check(_assigned.size() == 2, "match_assigned only for the 2 humans")
	var ticket := MpMatchFiles.read_json(MpMatchFiles.path_of(ROOT, mid, MpMatchFiles.TICKET))
	var seats: Array = ticket.get("seats", [])
	_check(seats.size() == 4, "the ticket has 4 rows (default builder)")
	var hashed := 0
	var bots := 0
	for row: Dictionary in seats:
		if row.has("token_sha256"):
			hashed += 1
		if bool(row.get("bot", false)) and not row.has("token_sha256") and not row.has("token"):
			bots += 1
	_check(hashed == 2 and bots == 2, "2 rows with a token hash and 2 bot rows without one")
	_check(int(seats[3].get("slot", 0)) == 4 and str(seats[3]["meta"].get("tag", "")) == "q", "a bot row keeps its slot and meta")
	var agent := MpMatchAgent.new()
	agent.auto_start = false
	agent.config = _rooms_config()
	add_child(agent)
	_check(agent.start(MpMatchFiles.path_of(ROOT, mid, MpMatchFiles.TICKET)), "the agent loads the ticket")
	var human_token := str(_assigned[0]["token"])
	_check(int(MpKit.admission.call(11, human_token)) == 1, "the agent admits a human token into its slot")
	_check(int(MpKit.admission.call(12, "")) == 0, "an empty token is never admitted")
	_check(agent.connected_slots().is_empty() and agent.seat_meta(3).is_empty() and agent.seat_meta(4).is_empty(), "bot seats are not seats of the agent")
	MpKit.admission = Callable()
	agent.queue_free()


## RFC-049 049f: the Sacrifice rules over the same rooms: 2v2 has 4 seats, 1v1 keeps 2, a mode must fit its map, bots go to `ai_seats`.
func _case_sacrifice_glue() -> void:
	_fresh()
	var rules := SacrificeRoomRules.new()
	rules.include_test_maps = true
	_rooms.options_validator = rules.are_options_valid
	_rooms.ticket_builder = rules.build_ticket
	_rooms.seat_count_for = rules.seat_count_for
	_rooms.bot_validator = rules.is_valid_bot
	_rooms.meta_validator = rules.is_valid_pick
	for sid in ["a", "b", "c", "d"]:
		_rooms.connect_session(sid, sid)
	_check(_rooms.create_room("a", {"mode": "ffa4", "world": "high_noon"}) == "bad_options", "ffa4 on high_noon: bad_options")
	_check(_rooms.create_room("a", {"mode": "2v2"}) == "bad_options", "2v2 without a map (high_noon by default): bad_options")
	_check(_rooms.create_room("a", {"mode": "nope", "world": "test_flat4"}) == "bad_options", "an unknown mode: bad_options")
	_check(_rooms.create_room("a", {"mode": "2v2", "world": "test_flat4"}) == "", "2v2 on test_flat4")
	var r := _rooms.room_of("a")
	_check(_rooms.snapshot(r)["seats"].size() == 4, "a 2v2 room has 4 seats")
	_check(_rooms.create_room("b", {"mode": "1v1"}) == "", "1v1 room")
	_check(_rooms.snapshot(_rooms.room_of("b"))["seats"].size() == 2, "a 1v1 room keeps 2 seats")
	_check(_rooms.create_room("c", {}) == "", "a room with no mode")
	_check(_rooms.snapshot(_rooms.room_of("c"))["seats"].size() == 2, "no mode: 2 seats")
	_check(_rooms.set_seat_bot("a", 2, {"god": "nope"}) == "bad_bot", "a bot with an unknown god: bad_bot")
	_check(_rooms.set_seat_bot("a", 2, {"level": 3}) == "bad_bot", "a bot with an unknown key: bad_bot")
	_check(_rooms.set_seat_bot("a", 2, {}) == "", "a bot with no god (drawn later)")
	_check(_rooms.set_seat_bot("a", 3, {"god": "pyro"}) == "", "a bot with pyro")
	_check(_rooms.join_room("d", r) == "", "the second human joins")
	_rooms.set_seat_meta("a", {"wizard": "cwa0", "god": "james"})
	_rooms.set_seat_meta("d", {"wizard": "cwa1", "god": "stratos"})
	_rooms.set_ready("a", true)
	_rooms.set_ready("d", true)
	_check(_rooms.state_of(r) == MpLobbyRooms.State.COUNTDOWN, "2 humans ready + 2 bots: COUNTDOWN")
	_rooms.tick(CONFIG.countdown_s + 0.1)
	var mid := _rooms.match_id_of(r)
	var ticket := MpMatchFiles.read_json(MpMatchFiles.path_of(ROOT, mid, MpMatchFiles.TICKET))
	var seats: Array = ticket.get("seats", [])
	var ai: Array = ticket.get("ai_seats", [])
	_check(seats.size() == 2 and seats.all(func(x: Dictionary) -> bool: return x.has("token_sha256")), "the ticket has 2 rows with a token")
	_check(ai.size() == 2 and int(ai[0]["slot"]) == 3 and str(ai[0]["god"]) == "" and int(ai[1]["slot"]) == 4 and str(ai[1]["god"]) == "pyro", "the ticket has 2 ai_seats (slots 3, 4)")
	_check(str(ticket.get("mode", "")) == "2v2" and str(ticket.get("world", "")) == "test_flat4" and int(ticket.get("ticket_version", 0)) == 2, "ticket v2: mode and world")
	_check(MatchTicketGlue.world_is_valid(ticket), "the dedicated accepts that ticket")
	_check(not MatchTicketGlue.world_is_valid({"world": "high_noon", "mode": "2v2"}), "the dedicated turns away 2v2 on high_noon")
	_check(not MatchTicketGlue.world_is_valid({"mode": "nope"}), "the dedicated turns away an unknown mode")
	_check(MatchTicketGlue.world_is_valid({"world": "high_noon"}), "a v1 ticket (no mode) is a 1v1")
	_check(String(MatchTicketGlue.setup_from_ticket(ticket).mode_tag) == "2v2", "the setup of the ticket carries the mode")
	rules.free()


# --- helpers ---------------------------------------------------------------------------

func _rooms_config() -> MpLobbyConfig:
	return CONFIG.duplicate() as MpLobbyConfig


## New launcher (stub runner, own folder) and new rooms. `overrides`: config fields for this case.
func _fresh(overrides: Dictionary = {}) -> void:
	if _launcher != null:
		_launcher.queue_free()
	MpMatchFiles.remove_dir(ROOT)
	_runner = STUB.duplicate() as MpProcessRunnerStub
	var config := _rooms_config()
	config.matches_root = ROOT
	for field in overrides:
		config.set(field, overrides[field])
	_launcher = MpMatchLauncher.new()
	_launcher.config = config.duplicate() as MpLobbyConfig
	_launcher.runner = _runner
	_launcher.reap_on_ready = false
	add_child(_launcher)
	_rooms = MpLobbyRooms.new(config, _launcher)
	_rooms.meta_validator = _meta_ok
	_rooms.options_validator = func(o: Dictionary) -> bool: return not o.has("bad")
	_errors.clear()
	_assigned.clear()
	_closed.clear()
	_expired.clear()
	_cancelled.clear()
	_started.clear()
	_rooms.room_error.connect(func(id: String, code: String) -> void: _errors.append("%s:%s" % [id, code]))
	_rooms.match_assigned.connect(func(_id: String, sid: String, port: int, token: String) -> void:
		_assigned.append({"session_id": sid, "port": port, "token": token}))
	_rooms.room_closed.connect(func(id: String) -> void: _closed.append(id))
	_rooms.session_expired.connect(func(sid: String) -> void: _expired.append(sid))
	_rooms.countdown_cancelled.connect(func(id: String) -> void: _cancelled.append(id))
	_rooms.countdown_started.connect(func(id: String) -> void: _started.append(id))


func _meta_ok(meta: Dictionary) -> bool:
	return str(meta.get("pick", "")) != "bad"


## `first` creates a room that `second` joins (a spare session `c` is also connected).
## `ready`: both pick (x, y) and ready up, which starts the COUNTDOWN.
func _full_room(ready: bool = false, first: String = "a", second: String = "b") -> String:
	for sid in [first, second, "c"]:
		if not _rooms.has_session(sid):
			_rooms.connect_session(sid, sid)
	_rooms.create_room(first, {"level": 1})
	var room_id := _rooms.room_of(first)
	_rooms.join_room(second, room_id)
	if ready:
		_rooms.set_seat_meta(first, {"pick": "x"})
		_rooms.set_seat_meta(second, {"pick": "y"})
		_rooms.set_ready(first, true)
		_rooms.set_ready(second, true)
	return room_id


func _seat_two(rooms: MpLobbyRooms, first: String, second: String) -> String:
	rooms.create_room(first)
	var room_id := rooms.room_of(first)
	rooms.join_room(second, room_id)
	rooms.set_seat_meta(first, {"pick": "x"})
	rooms.set_seat_meta(second, {"pick": "y"})
	rooms.set_ready(first, true)
	rooms.set_ready(second, true)
	return room_id


func _write_state(match_id: String, listening: bool, heartbeat_ms: int) -> void:
	MpMatchFiles.write_json(MpMatchFiles.path_of(ROOT, match_id, MpMatchFiles.STATE), {
		"pid": _launcher.pid_of(match_id), "listening": listening, "heartbeat_ms": heartbeat_ms,
	})


## The stub process exits after writing result.json; the launcher sees both on its next poll.
func _finish_match(match_id: String, result: Dictionary) -> void:
	MpMatchFiles.write_json(MpMatchFiles.path_of(ROOT, match_id, MpMatchFiles.RESULT), result)
	_runner.kill(_launcher.pid_of(match_id))
	_launcher.poll()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: %s" % label)
	else:
		_fails += 1
		print("FAIL: %s" % label)


func _cleanup() -> void:
	MpMatchFiles.remove_dir(ROOT)
