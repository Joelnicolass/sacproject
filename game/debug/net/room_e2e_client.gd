extends Node

## RFC-034 034e. One headless player of the end-to-end test (`agent/runs/run_034e.sh`): it goes through the room
## server like a person would, with the real autoloads of the game and no screen.
## lobby (MpLobby.client): connect, create the room (or join it by name), pick, ready, wait for `match_ready`;
## match (MpKit): join the dedicated with the ticket, take the slot, wait for the result.
## The client does not load the world (the script passes `--no-flow`): the dedicated runs the real match.
## Flags: --e2e-name --e2e-room --e2e-peer (the rival's name) --e2e-create --e2e-level --e2e-wizard --e2e-model
## --e2e-god --e2e-dir (shared folder for the ports) --e2e-room-tag --e2e-cross-tag (the other room's tag; makes this
## client try its ticket on the other room's dedicated, and a made-up ticket on its own) --e2e-join-delay-s
## --e2e-leave-after-s --e2e-expect-winner --e2e-expect-reason --lobby-port.
## RFC-049 049g (rooms with teams): --e2e-peers=A,B,C (all the other humans; replaces --e2e-peer) --e2e-mode=2v2 --e2e-world=test_flat4
## (room options of the creator) --e2e-bot-seats=2,3 [--e2e-bot-gods=pyro,] (the creator, as host, puts bots in those seats)
## --e2e-seats=4 (the seats of the room) --e2e-join-when-used=N (a joiner enters when N seats of the room are taken, so the seats fill in order) --e2e-lobby-delay-s (waits before looking for the room)
## --e2e-world-ready (says the world is loaded after getting the slot, so the dedicated seats the wizard and starts the match)
## --e2e-rejoin-after-s (with --e2e-leave-after-s: comes back with the same ticket and must get the same slot)
## --e2e-expect-winners=1,2 (the whole winning team, in the dedicated's result and in the room's).
## Prints `PASS …` / `FAIL …` per check, `E2E_RESULT …` and `E2E CLIENT <name> PASS|FAIL`; exit 0 / 1.

const LOCAL_HOST := "127.0.0.1"
const GLOBAL_TIMEOUT_S := 150.0
const STEP_S := 40.0
const REJECT_S := 8.0
const FAKE_TOKEN := "00000000000000000000000000000000"

var _name: String = ""
var _fails: int = 0
var _finished: bool = false
var _rejected: String = ""
var _slot: int = 0
var _session_ended: Dictionary = {}
var _lobby_result: Dictionary = {}
var _match: Dictionary = {}
var _seat_count: int = 2


func _ready() -> void:
	_name = MpBoot.user_value("e2e-name", "?")
	var tree := get_tree()
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = GLOBAL_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("E2E CLIENT %s FAIL: global timeout" % _name)
		tree.quit(1))
	tree.root.add_child.call_deferred(timer)
	timer.start.call_deferred()
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	MpKit.session_ended.connect(func(data: Dictionary) -> void: _session_ended = data)
	MpLobby.client.match_ready.connect(func(host: String, port: int, token: String) -> void:
		_match = {"host": host, "port": port, "token": token})
	MpLobby.client.match_finished.connect(func(result: Dictionary) -> void: _lobby_result = result)
	_run()


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
	print("E2E CLIENT %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _seat_names() -> PackedStringArray:
	var out := PackedStringArray()
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if not bool(seat["free"]) and not bool(seat.get("bot", false)):
			out.append(str(seat["name"]))
	out.sort()
	return out


func _bot_seats() -> Array[int]:
	var out: Array[int] = []
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if bool(seat.get("bot", false)):
			out.append(int(seat["seat"]))
	return out


func _int_list(raw: String) -> Array[int]:
	var out: Array[int] = []
	for part in raw.split(",", false):
		out.append(int(part))
	return out


func _my_meta() -> Dictionary:
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if bool(seat.get("you", false)):
			return seat.get("meta", {})
	return {}


func _run() -> void:
	var client := MpLobby.client
	var room_name := MpBoot.user_value("e2e-room", "")
	var peers := PackedStringArray([MpBoot.user_value("e2e-peer", "")])
	if not MpBoot.user_value("e2e-peers", "").is_empty():
		peers = MpBoot.user_value("e2e-peers", "").split(",", false)
	var lobby_port := int(MpBoot.user_value("lobby-port", "7700"))
	_seat_count = int(MpBoot.user_value("e2e-seats", "2"))
	MpKit.configure(7777, _seat_count, 1)

	# --- lobby: room, pick, ready --------------------------------------------------------
	_check(MpLobby.connect_to(LOCAL_HOST, lobby_port, _name) == OK, "%s connects to the lobby" % _name)
	_check(await _until(func() -> bool: return client.is_online()), "%s is welcomed" % _name)
	if MpBoot.user_flag("e2e-create"):
		var options := {"level": int(MpBoot.user_value("e2e-level", "1"))}
		if not MpBoot.user_value("e2e-mode", "").is_empty():
			options["mode"] = MpBoot.user_value("e2e-mode", "")
		if not MpBoot.user_value("e2e-world", "").is_empty():
			options["world"] = MpBoot.user_value("e2e-world", "")
		client.create_room(room_name, false, options)
	else:
		var lobby_delay := float(MpBoot.user_value("e2e-lobby-delay-s", "0"))
		if lobby_delay > 0.0:
			await get_tree().create_timer(lobby_delay).timeout
		var joined := false
		## F350: with --e2e-join-when-used=N the client joins when the room already holds N seats taken (bots count), so the seats fill in
		## order whatever the startup jitter of the processes is (no wall-clock delay between the clients).
		var want_used := int(MpBoot.user_value("e2e-join-when-used", "-1"))
		for _i in 400:
			client.refresh_rooms()
			await get_tree().create_timer(0.2).timeout
			for row: Dictionary in client.rooms:
				if str(row["name"]) == room_name and not joined and (want_used < 0 or int(row.get("seats_used", 0)) == want_used):
					joined = true
					client.join_room(str(row["id"]))
			if joined:
				break
		_check(joined, "%s finds the room %s" % [_name, room_name])
	var names := PackedStringArray([_name])
	names.append_array(peers)
	names.sort()
	var bot_seats := _int_list(MpBoot.user_value("e2e-bot-seats", ""))
	if MpBoot.user_flag("e2e-create") and not bot_seats.is_empty():
		_check(await _until(func() -> bool: return client.room.get("seats", []).size() == _seat_count), "%s sees a room with %d seats" % [_name, _seat_count])
		_check(client.is_host(), "%s is the host of its room" % _name)
		var gods := MpBoot.user_value("e2e-bot-gods", "").split(",")
		for i in bot_seats.size():
			var god := gods[i] if i < gods.size() else ""
			client.set_seat_bot(bot_seats[i], {"god": god} if not god.is_empty() else {})
	_check(await _until(func() -> bool: return _seat_names() == names), "%s sees only its room: %s" % [_name, ", ".join(names)])
	if not bot_seats.is_empty():
		_check(await _until(func() -> bool: return _bot_seats() == bot_seats), "%s sees the bots in seats %s" % [_name, str(bot_seats)])
	_check(client.room.get("seats", []).size() == _seat_count, "%s: the room has %d seats" % [_name, _seat_count])
	var seat := client.my_seat()
	var want_slot := seat + 1
	if MpBoot.user_value("e2e-seat", "") != "":
		_check(seat == int(MpBoot.user_value("e2e-seat", "-1")), "%s sits in seat %s (got %d)" % [_name, MpBoot.user_value("e2e-seat", ""), seat])
	client.set_pick({
		"wizard": MpBoot.user_value("e2e-wizard", "cwa0"), "model": MpBoot.user_value("e2e-model", "jnwr"),
		"god": MpBoot.user_value("e2e-god", "james"),
	})
	_check(await _until(func() -> bool: return not _my_meta().is_empty()), "%s pick is in the room" % _name)
	client.set_ready(true)
	_check(await _until(func() -> bool: return not _match.is_empty()), "%s gets match_ready" % _name)
	if _match.is_empty():
		_finish()
		return
	var port := int(_match["port"])
	var token := str(_match["token"])
	print("E2E_MATCH %s room=%s seat=%d port=%d" % [_name, room_name, seat, port])
	var dir := MpBoot.user_value("e2e-dir", "")
	var tag := MpBoot.user_value("e2e-room-tag", "")
	if not dir.is_empty() and not tag.is_empty():
		_write_port(dir, tag, port)

	# --- the dedicated: wrong tickets first, then the real one ---------------------------
	var cross := MpBoot.user_value("e2e-cross-tag", "")
	if not cross.is_empty() and not dir.is_empty():
		_check(await _until(func() -> bool: return _read_port(dir, cross) > 0), "%s sees the port of room %s" % [_name, cross])
		var other_port := _read_port(dir, cross)
		if other_port > 0:
			await _expect_rejection(other_port, token, "the ticket of room %s on the dedicated of room %s" % [tag, cross])
		await _expect_rejection(port, FAKE_TOKEN, "a made-up ticket on the dedicated of room %s" % tag)
	var delay := float(MpBoot.user_value("e2e-join-delay-s", "0"))
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_rejected = ""
	_slot = 0
	_check(MpKit.join(str(_match["host"]), port, token) == OK, "%s joins its dedicated" % _name)
	_check(await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty()), "%s gets a slot" % _name)
	_check(_rejected.is_empty(), "%s is not rejected by its own dedicated" % _name)
	_check(_slot == want_slot, "%s has the slot of its seat (%d, got %d)" % [_name, want_slot, _slot])
	print("E2E_SLOT %s slot=%d" % [_name, _slot])
	if MpBoot.user_flag("e2e-world-ready"):
		MpKit.request_world_ready()

	# --- the end ---------------------------------------------------------------------------
	var leave_after := float(MpBoot.user_value("e2e-leave-after-s", "0"))
	var left := false
	if leave_after > 0.0:
		await get_tree().create_timer(leave_after).timeout
		MpKit.leave()
		left = true
		print("E2E_LEFT %s" % _name)
		var rejoin_after := float(MpBoot.user_value("e2e-rejoin-after-s", "0"))
		if rejoin_after > 0.0:
			await get_tree().create_timer(rejoin_after).timeout
			_rejected = ""
			_slot = 0
			_check(MpKit.join(str(_match["host"]), port, token) == OK, "%s joins again with the same ticket" % _name)
			_check(await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty()), "%s gets a slot again" % _name)
			_check(_rejected.is_empty() and _slot == want_slot, "%s comes back to the same slot (%d, got %d)" % [_name, want_slot, _slot])
			print("E2E_BACK %s slot=%d" % [_name, _slot])
			if MpBoot.user_flag("e2e-world-ready"):
				MpKit.request_world_ready()
			left = false
	if not left:
		_check(await _until(func() -> bool: return not _session_ended.is_empty()), "%s gets session_ended from its dedicated" % _name)
	_check(await _until(func() -> bool: return not _lobby_result.is_empty()), "%s gets the result in the lobby room" % _name)
	var winner := int(MpBoot.user_value("e2e-expect-winner", "-1"))
	var reason := MpBoot.user_value("e2e-expect-reason", "")
	var result: Dictionary = _lobby_result if left else _session_ended
	if not MpBoot.user_value("e2e-expect-winners", "").is_empty():
		var want_winners := _int_list(MpBoot.user_value("e2e-expect-winners", ""))
		for source: Dictionary in [result, _lobby_result]:
			var got: Array[int] = []
			for slot in source.get("winner_slots", []):
				got.append(int(slot))
			_check(got == want_winners, "%s result winner_slots is %s (got %s)" % [_name, str(want_winners), str(got)])
		winner = want_winners[0]
		var won := want_winners.has(want_slot)
		var prefix := "LOBBY_RESULT_TEAM_" if want_winners.size() >= 2 else "LOBBY_RESULT_"
		var text_key := prefix + ("WON" if won else "LOST") + ("_ABANDON" if reason == "abandon" else "")
		_check(LobbyText.result_text(_lobby_result, want_slot) == UiText.t(text_key), "%s: the room says %s" % [_name, text_key])
	_check(int(result.get("winner_slot", -2)) == winner, "%s result winner is slot %d (got %s)" % [_name, winner, str(result.get("winner_slot"))])
	_check(str(result.get("reason", "")) == reason, "%s result reason is %s (got %s)" % [_name, reason, str(result.get("reason"))])
	_check(_lobby_result.get("match_id", "x") == result.get("match_id", "y"), "%s lobby and dedicated agree on the match" % _name)
	if not left:
		_check(int(_session_ended.get("seed", 0)) == int(_lobby_result.get("seed", -1)), "%s lobby and dedicated agree on the seed" % _name)
	print("E2E_RESULT name=%s room=%s slot=%d winner=%d reason=%s seed=%d match=%s" % [
		_name, room_name, want_slot, int(_lobby_result.get("winner_slot", -1)), str(_lobby_result.get("reason", "")),
		int(_lobby_result.get("seed", 0)), str(_lobby_result.get("match_id", ""))])
	MpKit.leave()
	MpLobby.client.close_connection()
	_finish()


## Joins `port` with `token` and expects the dedicated to say no: a rejection and no slot.
func _expect_rejection(port: int, token: String, what: String) -> void:
	_rejected = ""
	_slot = 0
	if MpKit.join(LOCAL_HOST, port, token) != OK:
		_check(false, "%s: join starts" % what)
		return
	var rejected := await _until(func() -> bool: return not _rejected.is_empty(), REJECT_S)
	_check(rejected and _slot == 0, "%s is rejected (%s)" % [what, _rejected])
	MpKit.leave()
	await get_tree().create_timer(0.3).timeout


func _write_port(dir: String, tag: String, port: int) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open("%s/%s.port" % [dir, tag], FileAccess.WRITE)
	if file != null:
		file.store_string(str(port))
		file.close()


func _read_port(dir: String, tag: String) -> int:
	var path := "%s/%s.port" % [dir, tag]
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_string(path).strip_edges().to_int()
