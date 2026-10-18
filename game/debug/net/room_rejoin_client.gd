extends Node

## RFC-034 034g (F184). One headless process of `agent/run_034g.sh`: reconnection through the real room server, no screen.
## `--e2e-role=a`: creates the room; drops the lobby and resumes it (by hand, then by `auto_resume`) with the same seat; plays;
##   drops the dedicated while the intruder tries its ticket, and comes back with the same ticket into the same slot.
## `--e2e-role=b`: joins the room; sits in the dedicated after A is back, leaves for good, waits past `rejoin_grace_s` and is turned away.
## `--e2e-role=c`: the intruder. Takes A's ticket (a file in `--e2e-dir`) while A is connected (alone in the dedicated): rejected.
## The server comes from `--lobby=host:port` (the kit's MpLobbyEndpoint, over data/net/lobby_endpoint.tres), like the game.
## Flags: --e2e-name --e2e-room --e2e-peer --e2e-dir --e2e-lobby-port (what --lobby must resolve to) --e2e-leave-wait-s.
## Prints `PASS …` / `FAIL …`, `E2E_LEFT`, `E2E_BACK`, `E2E_RESULT …` and `E2E REJOIN <name> PASS|FAIL`; exit 0 / 1.

const GLOBAL_TIMEOUT_S := 150.0
const STEP_S := 40.0
const REJECT_S := 8.0
## The wizard needs a moment in the dedicated before the drop, so the state it keeps is the one of a spawned wizard.
const SETTLE_S := 3.0

var _name: String = ""
var _role: String = ""
var _dir: String = ""
var _fails: int = 0
var _finished: bool = false
var _rejected: String = ""
var _slot: int = 0
var _session_ended: Dictionary = {}
var _lobby_result: Dictionary = {}
var _match: Dictionary = {}
var _resuming_seen: int = 0
var _join_failed: bool = false


func _ready() -> void:
	_name = MpBoot.user_value("e2e-name", "?")
	_role = MpBoot.user_value("e2e-role", "")
	_dir = MpBoot.user_value("e2e-dir", "")
	var tree := get_tree()
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = GLOBAL_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("E2E REJOIN %s FAIL: global timeout" % _name)
		tree.quit(1))
	tree.root.add_child.call_deferred(timer)
	timer.start.call_deferred()
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	MpKit.session_ended.connect(func(data: Dictionary) -> void: _session_ended = data)
	MpLobby.client.match_ready.connect(func(host: String, port: int, token: String) -> void:
		_match = {"host": host, "port": port, "token": token})
	MpLobby.client.match_finished.connect(func(result: Dictionary) -> void: _lobby_result = result)
	MpLobby.client.lobby_resuming.connect(func(_attempt: int) -> void: _resuming_seen += 1)
	MpKit.join_failed.connect(func() -> void: _join_failed = true)
	MpKit.configure(7777, 2, 1)
	if _role == "c":
		_run_intruder()
	else:
		_run_player()


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
	print("E2E REJOIN %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
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
		if not bool(seat["free"]):
			out.append(str(seat["name"]))
	out.sort()
	return out


func _my_seat_row() -> Dictionary:
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if bool(seat.get("you", false)):
			return seat
	return {}


# --- player (a, b) -----------------------------------------------------------------------

func _run_player() -> void:
	var client := MpLobby.client
	var room_name := MpBoot.user_value("e2e-room", "")
	var peer_name := MpBoot.user_value("e2e-peer", "")
	var creator := _role == "a"

	# the server is found the way the game finds it: the endpoint resource with the --lobby= flag over it
	var endpoint := (load("res://data/net/lobby_endpoint.tres") as MpLobbyEndpoint).resolved()
	_check(endpoint.port == int(MpBoot.user_value("e2e-lobby-port", "0")), "--lobby= gives the port of the test server (%d)" % endpoint.port)
	_check(MpLobby.connect_to(endpoint.host, endpoint.port, _name) == OK, "%s connects to the lobby" % _name)
	_check(await _until(func() -> bool: return client.is_online()), "%s is welcomed" % _name)
	if creator:
		client.create_room(room_name, false, {"level": 1})
	else:
		var joined := false
		for _i in 80:
			client.refresh_rooms()
			await get_tree().create_timer(0.5).timeout
			for row: Dictionary in client.rooms:
				if str(row["name"]) == room_name and not joined:
					joined = true
					client.join_room(str(row["id"]))
			if joined:
				break
		_check(joined, "%s finds the room %s" % [_name, room_name])
	var names := PackedStringArray([_name, peer_name])
	names.sort()
	_check(await _until(func() -> bool: return _seat_names() == names), "%s sees both players" % _name)
	client.set_pick({
		"wizard": MpBoot.user_value("e2e-wizard", "cwa0"), "model": MpBoot.user_value("e2e-model", "jnwr"),
		"god": MpBoot.user_value("e2e-god", "james"),
	})
	_check(await _until(func() -> bool: return not (_my_seat_row().get("meta", {}) as Dictionary).is_empty()), "%s pick is in the room" % _name)
	if creator:
		await _lobby_resume_cases()
	var seat := client.my_seat()
	var want_slot := seat + 1
	client.set_ready(true)
	_check(await _until(func() -> bool: return not _match.is_empty()), "%s gets match_ready" % _name)
	if _match.is_empty():
		_finish()
		return
	var token := str(_match["token"])
	var port := int(_match["port"])
	_write("%s.token" % _role, token)
	_write("%s.port" % _role, str(port))

	# --- the dedicated -----------------------------------------------------------------------
	if not creator:
		## B sits down after A is back: with A alone in the dedicated a free transport slot lets the intruder's ticket reach the
		## admission (with both seats connected the ENet host, sized for the players, does not even take the third connection).
		_check(await _until(func() -> bool: return _exists("a.back"), 90.0), "%s waits for A to be back before joining" % _name)
	_check(await _join_match(want_slot), "%s joins its dedicated and takes slot %d" % [_name, want_slot])
	await get_tree().create_timer(SETTLE_S).timeout
	_write("%s.joined" % _role, "1")

	if creator:
		_check(await _until(func() -> bool: return _exists("c.done"), 60.0), "the intruder finished its attempt")
		await get_tree().create_timer(1.0).timeout
		_check(MpKit.is_networked() and MpKit.local_slot() == want_slot, "%s still holds slot %d after the intruder's attempt" % [_name, want_slot])
		MpKit.leave()
		print("E2E_LEFT %s" % _name)
		await get_tree().create_timer(2.0).timeout
		_check(await _join_match(want_slot), "%s comes back with the same ticket to slot %d" % [_name, want_slot])
		print("E2E_BACK %s slot=%d" % [_name, _slot])
		_write("a.back", "1")
		_check(await _until(func() -> bool: return not _session_ended.is_empty(), 90.0), "%s gets session_ended from its dedicated" % _name)
		_expect_result(_session_ended, 1, "abandon")
	else:
		MpKit.leave()
		print("E2E_LEFT %s" % _name)
		await get_tree().create_timer(float(MpBoot.user_value("e2e-leave-wait-s", "10"))).timeout
		_rejected = ""
		_slot = 0
		_join_failed = false
		var err := MpKit.join(str(_match["host"]), port, token)
		if err == OK:
			var refused := await _until(func() -> bool: return not _rejected.is_empty() or _join_failed, REJECT_S)
			_check(refused or _slot == 0, "%s: a return after rejoin_grace_s is refused (%s)" % [_name, _rejected if not _rejected.is_empty() else "no connection"])
		else:
			_check(true, "%s: a return after rejoin_grace_s is refused (the dedicated is gone)" % _name)
		_check(_slot == 0, "%s got no slot after the grace" % _name)
		MpKit.leave()
	_check(await _until(func() -> bool: return not _lobby_result.is_empty()), "%s gets the result in the lobby room" % _name)
	_expect_result(_lobby_result, 1, "abandon")
	print("E2E_RESULT name=%s slot=%d winner=%d reason=%s match=%s" % [
		_name, want_slot, int(_lobby_result.get("winner_slot", -1)), str(_lobby_result.get("reason", "")), str(_lobby_result.get("match_id", ""))])
	client.close_connection()
	_finish()


## The lobby drops twice: by hand (`resume()`) and the way the game does it (`auto_resume`): same session, same seat, same room.
func _lobby_resume_cases() -> void:
	var client := MpLobby.client
	var sid := client.session_id
	var seat := client.my_seat()
	var room_id := str(client.room.get("id", ""))
	client.close_connection()
	await get_tree().create_timer(1.5).timeout
	_check(client.resume() == OK, "resume() opens the link again")
	_check(await _until(func() -> bool: return client.is_online() and not client.room.is_empty()), "the lobby is back (by hand)")
	_check(client.session_id == sid, "same session after resume()")
	_check(client.my_seat() == seat and str(client.room.get("id", "")) == room_id, "same seat %d in the same room after resume()" % seat)
	_check(bool(_my_seat_row().get("connected", false)), "the server sees the seat connected")

	client.auto_resume = true
	client.resume_window_s = 30.0
	client.resume_retry_s = 1.0
	_resuming_seen = 0
	# a drop the client did not ask for: the link goes down under it, as a lost connection does
	client._peer.close()
	client._on_server_disconnected.call_deferred()
	_check(await _until(func() -> bool: return _resuming_seen > 0, 5.0), "auto_resume announces the drop (lobby_resuming)")
	_check(await _until(func() -> bool: return client.is_online() and not client.room.is_empty()), "the lobby is back (auto_resume)")
	_check(client.session_id == sid and client.my_seat() == seat and str(client.room.get("id", "")) == room_id, "same session and seat %d after auto_resume" % seat)
	_check(not client.is_resuming(), "auto_resume is over once welcomed")
	client.auto_resume = false


## Joins the dedicated with the ticket; true if it got `want_slot`. Then says the world is loaded (the dedicated spawns the wizard).
func _join_match(want_slot: int) -> bool:
	_rejected = ""
	_slot = 0
	if MpKit.join(str(_match["host"]), int(_match["port"]), str(_match["token"])) != OK:
		return false
	var got := await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty())
	if not got or _slot != want_slot:
		return false
	MpKit.request_world_ready()
	return true


func _expect_result(result: Dictionary, winner: int, reason: String) -> void:
	_check(int(result.get("winner_slot", -2)) == winner and str(result.get("reason", "")) == reason,
		"%s: result %s, winner slot %d (got %s, %s)" % [_name, reason, winner, str(result.get("reason")), str(result.get("winner_slot"))])


# --- intruder (c) ------------------------------------------------------------------------

func _run_intruder() -> void:
	_check(await _until(func() -> bool: return _exists("a.joined") and _exists("a.token") and _exists("a.port"), 90.0), "the intruder sees A inside its dedicated")
	var token := _read("a.token")
	var port := int(_read("a.port"))
	_rejected = ""
	_slot = 0
	_check(MpKit.join("127.0.0.1", port, token) == OK, "the intruder joins with A's ticket")
	var started := Time.get_ticks_msec()
	## The dedicated may be busy loading its world for a while: a longer wait than the one of a late return.
	var refused := await _until(func() -> bool: return not _rejected.is_empty() or _slot != 0 or _join_failed, 30.0)
	_check(refused and _slot == 0 and not _rejected.is_empty(), "A's ticket on a third client, with A connected, is rejected (%s, after %d ms)" % [_rejected, Time.get_ticks_msec() - started])
	MpKit.leave()
	await get_tree().create_timer(0.3).timeout
	_write("c.done", "1")
	_finish()


# --- files shared between the processes ---------------------------------------------------

func _write(file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f := FileAccess.open("%s/%s" % [_dir, file], FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _exists(file: String) -> bool:
	return FileAccess.file_exists("%s/%s" % [_dir, file])


func _read(file: String) -> String:
	return FileAccess.get_file_as_string("%s/%s" % [_dir, file]).strip_edges()
