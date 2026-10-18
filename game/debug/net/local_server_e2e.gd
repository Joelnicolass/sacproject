extends Node

## RFC-034 034m. One headless player of the «Servidor local» test (`agent/run_034m.sh`). No screens: the real nodes of the game
## (`LocalServerHost`, `LocalServerEndpoint`, `MpKit`) do what the buttons do. The clients do not load the world (`--no-flow`).
## `--e2e-role=host`: starts the local server (launches the dedicated), publishes address/port/code in `--e2e-dir/local.json`
##   (or just prints them), joins with its own credential (slot 1), waits for the result and for the server to close itself.
## `--e2e-role=rival`: reads local.json (or `--e2e-address=host:port --e2e-code=…`), joins with the code (slot 2), waits for the result.
## `--e2e-role=intruder`: without credential, with a made-up code, and with the code of the seat the rival already uses: three rejections.
## Other flags: --e2e-ready (rival: say world_ready) --e2e-expect-winner --e2e-expect-reason --e2e-god (rival's god) --e2e-transport.
## Prints `PASS …` / `FAIL …` per check and `E2E LOCAL <role> PASS|FAIL`; exit 0 / 1.

const HOST_SCENE := "res://scenes/net/local_server_host.tscn"
const GLOBAL_TIMEOUT_S := 150.0
const STEP_S := 40.0
const REJECT_S := 12.0
const FAKE_CODE := "00000000000000000000000000000000"
const DEFAULT_PORT := 7710
const INFO_FILE := "local.json"
const RIVAL_IN_FILE := "rival_in.flag"

var _role: String = ""
var _fails: int = 0
var _finished: bool = false
var _rejected: String = ""
var _lost: bool = false
var _slot: int = 0
var _session_ended: Dictionary = {}


func _ready() -> void:
	_role = MpBoot.user_value("e2e-role", "host")
	var tree := get_tree()
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = GLOBAL_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("E2E LOCAL %s FAIL: global timeout" % _role)
		tree.quit(1))
	tree.root.add_child.call_deferred(timer)
	timer.start.call_deferred()
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	MpKit.server_lost.connect(func() -> void: _lost = true)
	MpKit.session_ended.connect(func(data: Dictionary) -> void: _session_ended = data)
	MpKit.configure(7777, 2, 1)
	match _role:
		"host":
			_run_host()
		"rival":
			_run_rival()
		"intruder":
			_run_intruder()
		_:
			print("FAIL unknown role %s" % _role)
			_fails += 1
			_finish()


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
	print("E2E LOCAL %s %s" % [_role, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _dir() -> String:
	return MpBoot.user_value("e2e-dir", "")


# --- host ------------------------------------------------------------------------------------------------------------
func _run_host() -> void:
	var ready_info := {}
	var closed := {"seen": false, "result": {}}
	var server := (load(HOST_SCENE) as PackedScene).instantiate() as LocalServerHost
	get_tree().root.add_child(server)
	## Lambdas capture locals by value: they fill the Dictionary, they do not replace it.
	server.server_ready.connect(func(address: String, port: int, code: String) -> void:
		ready_info["address"] = address
		ready_info["port"] = port
		ready_info["code"] = code)
	server.server_closed.connect(func(result: Dictionary) -> void:
		closed["seen"] = true
		closed["result"] = result)
	var pick := {"wizard": "cwa0", "god": "james"}
	var rival := {"wizard": LocalServerHost.DEFAULT_RIVAL_WIZARD, "god": MpBoot.user_value("e2e-god", "pyro")}
	_check(server.start(pick, rival, MpBoot.user_value("e2e-transport", "")) == OK, "the host launches the local dedicated")
	_check(await _until(func() -> bool: return not ready_info.is_empty()), "the dedicated listens and the host gets address, port and code")
	if ready_info.is_empty():
		server.stop()
		_finish()
		return
	var pid := server.launcher.pid_of(server.match_id)
	_check(pid > 0 and MpProcessRunner.pid_alive(pid), "the local dedicated process runs (pid %d)" % pid)
	_check(str(ready_info["code"]).length() >= 16 and server.host_token != server.rival_code, "two different credentials of 16+ characters")
	_check(int(ready_info["port"]) == server.launcher.port_of(server.match_id), "the port shown is the one of the dedicated")
	print("E2E_LOCAL host ready address=%s port=%d code=%s" % [ready_info["address"], int(ready_info["port"]), ready_info["code"]])
	_write_info(ready_info)
	# the host joins as a normal client with its own credential
	_check(MpKit.join(LocalServerHost.LOOPBACK, int(ready_info["port"]), server.host_token) == OK, "the host joins its dedicated")
	_check(await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty()), "the host gets a slot")
	_check(_slot == LocalServerHost.HOST_SLOT, "the host has slot 1 (got %d)" % _slot)
	_check(await _until(func() -> bool: return not _session_ended.is_empty(), 90.0), "the host gets session_ended from the dedicated")
	var winner := int(MpBoot.user_value("e2e-expect-winner", "1"))
	_check(int(_session_ended.get("winner_slot", -2)) == winner, "the result winner is slot %d (got %s)" % [winner, str(_session_ended.get("winner_slot"))])
	_check(str(_session_ended.get("reason", "")) == MpBoot.user_value("e2e-expect-reason", "result"), "the result reason is %s" % MpBoot.user_value("e2e-expect-reason", "result"))
	# still connected: the server closes by itself after the match (match_ended, not host_left)
	_check(await _until(func() -> bool: return bool(closed["seen"]), 40.0), "the local server closes itself after the match")
	_check(not (closed["result"] as Dictionary).is_empty() and str((closed["result"] as Dictionary).get("reason", "")) == "result", "it closed with the result of the match, not by failure")
	_check(pid > 0 and not MpProcessRunner.pid_alive(pid), "the local dedicated process is gone")
	print("E2E_RESULT role=host slot=%d winner=%d reason=%s" % [_slot, int(_session_ended.get("winner_slot", -1)), str(_session_ended.get("reason", ""))])
	MpKit.leave()
	_finish()


func _write_info(info: Dictionary) -> void:
	var dir := _dir()
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open("%s/%s" % [dir, INFO_FILE], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info))
		file.close()


## address:port and code, from the flags or from the host's file.
func _read_info() -> Dictionary:
	var address := MpBoot.user_value("e2e-address", "")
	var code := MpBoot.user_value("e2e-code", "")
	if not address.is_empty() and not code.is_empty():
		return {"endpoint": address, "code": code}
	var path := "%s/%s" % [_dir(), INFO_FILE]
	if _dir().is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	var info: Dictionary = parsed
	var host := LocalServerHost.LOOPBACK
	return {"endpoint": LocalServerEndpoint.format(host, int(info.get("port", 0))), "code": str(info.get("code", ""))}


# --- rival -----------------------------------------------------------------------------------------------------------
func _run_rival() -> void:
	_check(await _until(func() -> bool: return not _read_info().is_empty(), 60.0), "the rival gets the address and the code")
	var info := _read_info()
	if info.is_empty():
		_finish()
		return
	var target := LocalServerEndpoint.parse(str(info["endpoint"]), DEFAULT_PORT)
	_check(bool(target["ok"]), "the address:port the rival typed is valid")
	var code := LocalServerEndpoint.clean_code(" %s " % str(info["code"]).to_upper())
	_check(MpKit.join(str(target["host"]), int(target["port"]), code) == OK, "the rival joins with the code")
	_check(await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty()), "the rival gets a slot")
	_check(_rejected.is_empty(), "the rival is not rejected")
	_check(_slot == LocalServerHost.RIVAL_SLOT, "the rival has slot 2 (got %d)" % _slot)
	_write_flag(RIVAL_IN_FILE)
	## `--e2e-ready`: this client has no world, but tells the dedicated it "loaded" (a windowed host loads the real one and the match waits for both).
	if MpBoot.user_flag("e2e-ready"):
		MpKit.request_world_ready()
	_check(await _until(func() -> bool: return not _session_ended.is_empty(), 90.0), "the rival gets session_ended from the dedicated")
	var winner := int(MpBoot.user_value("e2e-expect-winner", "1"))
	_check(int(_session_ended.get("winner_slot", -2)) == winner, "the result winner is slot %d (got %s)" % [winner, str(_session_ended.get("winner_slot"))])
	print("E2E_RESULT role=rival slot=%d winner=%d reason=%s" % [_slot, int(_session_ended.get("winner_slot", -1)), str(_session_ended.get("reason", ""))])
	MpKit.leave()
	_finish()


func _write_flag(name: String) -> void:
	if _dir().is_empty():
		return
	var file := FileAccess.open("%s/%s" % [_dir(), name], FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()


# --- intruder --------------------------------------------------------------------------------------------------------
func _run_intruder() -> void:
	_check(await _until(func() -> bool: return not _read_info().is_empty(), 60.0), "the intruder finds the address")
	var info := _read_info()
	if info.is_empty():
		_finish()
		return
	var target := LocalServerEndpoint.parse(str(info["endpoint"]), DEFAULT_PORT)
	var host := str(target["host"])
	var port := int(target["port"])
	# the rival must be seated first, so the third attempt really is about a seat that is taken
	_check(await _until(func() -> bool: return FileAccess.file_exists("%s/%s" % [_dir(), RIVAL_IN_FILE]), 60.0), "the intruder waits for the rival to sit")
	await _expect_no_seat(host, port, "", "without any credential")
	await _expect_no_seat(host, port, FAKE_CODE, "with a made-up code")
	await _expect_no_seat(host, port, str(info["code"]), "with the code of the seat the rival already uses")
	_finish()


## Joins with `credential` and expects: no slot, and the dedicated says no (a rejection, or the link closed).
func _expect_no_seat(host: String, port: int, credential: String, what: String) -> void:
	_rejected = ""
	_lost = false
	_slot = 0
	if MpKit.join(host, port, credential) != OK:
		_check(false, "%s: join starts" % what)
		return
	var answered := await _until(func() -> bool: return not _rejected.is_empty() or _lost, REJECT_S)
	_check(answered and _slot == 0, "a third player %s is rejected (%s)" % [what, _rejected if not _rejected.is_empty() else "link closed"])
	MpKit.leave()
	await get_tree().create_timer(0.3).timeout
