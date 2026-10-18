extends Node

## Headless check of MpMatchLauncher + MpMatchAgent with a real dedicated process (RFC-034 034b).
## Runs `match_agent_probe.tscn` as the dedicated. Closes by itself: prints
## `LAUNCHER PROBE PASS` (exit 0) or `LAUNCHER PROBE FAIL: ...` (exit 1).

const CHILD_SCENE := "res://debug/net/match_agent_probe.tscn"
const MATCH_ID := "probe_m1"
const SEAT_SLOT := 2
const LISTEN_TIMEOUT_S := 20.0
const STEP_TIMEOUT_S := 12.0
const TOTAL_TIMEOUT_S := 90.0
const ORPHAN_ID := "probe_orphan"

@onready var launcher: MpMatchLauncher = %Launcher

var _listening_port: int = 0
var _ended: Dictionary = {}
var _failed_reason: String = ""
var _rejected_reason: String = ""
var _slot: int = 0
var _session_ended: Dictionary = {}
var _done: bool = false
var _spawned_pids: Array[int] = []


func _ready() -> void:
	get_tree().create_timer(TOTAL_TIMEOUT_S).timeout.connect(func() -> void: _fail("global timeout"))
	launcher.base_args = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), CHILD_SCENE])
	launcher.match_listening.connect(func(_id: String, port: int) -> void: _listening_port = port)
	launcher.match_ended.connect(func(_id: String, result: Dictionary) -> void: _ended = result)
	launcher.match_failed.connect(func(_id: String, reason: String) -> void: _failed_reason = reason)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected_reason = reason)
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.session_ended.connect(func(data: Dictionary) -> void: _session_ended = data)
	_run()


func _run() -> void:
	var root := launcher.config.matches_root
	# 1. orphan from a previous run: registry says so, state.json agrees, the process still runs
	var orphan_pid := OS.create_process("/bin/sleep", PackedStringArray(["300"]))
	_spawned_pids.append(orphan_pid)
	_check(orphan_pid > 0, "dummy orphan spawned")
	MpMatchFiles.ensure_dir(MpMatchFiles.dir_of(root, ORPHAN_ID))
	MpMatchFiles.write_json(MpMatchFiles.path_of(root, ORPHAN_ID, MpMatchFiles.STATE), {"pid": orphan_pid})
	MpMatchFiles.write_json(MpMatchFiles.registry_path(root), {"matches": {ORPHAN_ID: {"pid": orphan_pid, "port": 0}}})
	_check(launcher.reap_orphans() == 1, "reap_orphans killed the leftover")
	_check(await _until(func() -> bool: return not MpProcessRunner.pid_alive(orphan_pid), 3.0), "orphan process is gone")

	# 2. launch one match, the cap holds the second
	var token := MpMatchFiles.new_token()
	var ticket := {"world": "probe", "seats": [{"slot": SEAT_SLOT, "token": token, "meta": {"name": "probe"}}]}
	_check(launcher.launch(MATCH_ID, ticket) == OK, "launch OK")
	_check(launcher.launch("probe_m2", ticket) == ERR_BUSY, "second launch is ERR_BUSY (max_matches)")
	var child_pid := launcher.pid_of(MATCH_ID)
	_spawned_pids.append(child_pid)
	var ticket_text := FileAccess.get_file_as_string(MpMatchFiles.path_of(root, MATCH_ID, MpMatchFiles.TICKET))
	_check(not ticket_text.contains(token), "ticket.json has no plain token")
	_check(ticket_text.contains(MpMatchFiles.sha256(token)), "ticket.json has the token hash")

	# 3. state.json reaches listening
	_check(await _until(func() -> bool: return _listening_port > 0, LISTEN_TIMEOUT_S), "match_listening (state.json listening)")

	# 4. a false ticket is rejected
	_check(MpKit.join("127.0.0.1", _listening_port, "fake-ticket") == OK, "join with fake ticket starts")
	_check(await _until(func() -> bool: return not _rejected_reason.is_empty(), STEP_TIMEOUT_S), "fake ticket rejected")
	_check(_slot == 0, "fake ticket got no slot")

	# 5. the real ticket lands on the ticket's slot (not slot 1, the connection-order one)
	_rejected_reason = ""
	await get_tree().create_timer(0.3).timeout
	_check(MpKit.join("127.0.0.1", _listening_port, token) == OK, "join with real ticket starts")
	_check(await _until(func() -> bool: return _slot != 0, STEP_TIMEOUT_S), "real ticket got a slot")
	_check(_slot == SEAT_SLOT, "slot is the ticket's slot (%d, got %d)" % [SEAT_SLOT, _slot])
	_check(_rejected_reason.is_empty(), "real ticket was not rejected")

	# 6. result: dedicated reports, clients are told, launcher sees the exit
	_check(await _until(func() -> bool: return not _session_ended.is_empty(), STEP_TIMEOUT_S), "client got session_ended")
	_check(await _until(func() -> bool: return not _ended.is_empty(), STEP_TIMEOUT_S), "match_ended")
	_check(int(_ended.get("winner_slot", 0)) == SEAT_SLOT, "result winner_slot is the seat")
	var disk := MpMatchFiles.read_json(MpMatchFiles.path_of(root, MATCH_ID, MpMatchFiles.RESULT))
	_check(str(disk.get("reason", "")) == "probe", "result.json on disk has the reason")
	_check(_failed_reason.is_empty(), "no match_failed (%s)" % _failed_reason)

	# 7. no leftovers
	_check(await _until(func() -> bool: return not MpProcessRunner.pid_alive(child_pid), 5.0), "dedicated process exited")
	var out: Array = []
	var code := OS.execute("pgrep", PackedStringArray(["-f", MATCH_ID]), out)
	_check(code == 1, "pgrep finds no process for %s (exit %d)" % [MATCH_ID, code])
	_check(launcher.active_count() == 0, "launcher has no active match")
	var registry := MpMatchFiles.read_json(MpMatchFiles.registry_path(root))
	_check((registry.get("matches", {}) as Dictionary).is_empty(), "registry is empty")
	if _done:
		return
	_done = true
	_cleanup()
	print("LAUNCHER PROBE PASS")
	get_tree().quit(0)


func _check(ok: bool, what: String) -> void:
	if _done:
		return
	if ok:
		print("PASS ", what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	if _done:
		return
	_done = true
	print("LAUNCHER PROBE FAIL: ", what)
	_cleanup()
	get_tree().quit(1)


func _cleanup() -> void:
	for id in launcher.active_ids():
		launcher.abort(id, "probe_cleanup")
	MpKit.leave()
	for pid in _spawned_pids:
		if MpProcessRunner.pid_alive(pid):
			OS.kill(pid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MpMatchFiles.registry_path(launcher.config.matches_root)))
	MpMatchFiles.remove_dir(MpMatchFiles.dir_of(launcher.config.matches_root, MATCH_ID))
	MpMatchFiles.remove_dir(MpMatchFiles.dir_of(launcher.config.matches_root, ORPHAN_ID))


func _until(cond: Callable, timeout_s: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end and not _done:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
	return cond.call()
