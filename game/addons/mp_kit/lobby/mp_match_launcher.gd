class_name MpMatchLauncher
extends Node

## Room-server side. One dedicated process per match: picks a free port from a range, writes the
## ticket, spawns the process, follows its state.json / result.json, and kills what stops
## beating, runs too long, or was left behind by a previous run. Nothing here knows the game.
## The caller (glue) builds the ticket content; the launcher adds match_id, port, room_pid,
## expires_ms and replaces each seat's `token` with `token_sha256`.

signal match_listening(match_id: String, port: int)
signal match_ended(match_id: String, result: Dictionary)
signal match_failed(match_id: String, reason: String)

@export var config: MpLobbyConfig
## Empty = OS.get_executable_path().
@export var executable: String = ""
## Engine arguments before the user args, e.g. `--headless --path <dir> <scene>`.
@export var base_args: PackedStringArray = PackedStringArray()
## User arguments every match process gets (after `--`).
@export var agent_args: PackedStringArray = PackedStringArray(["--dedicated"])
## Engine flag for the per-match log file. Empty = no log.
@export var log_file_flag: String = "--log-file"
@export var runner: MpProcessRunner
## Kill matches left in the registry by a previous run when this node enters the tree.
@export var reap_on_ready: bool = true
## Keep the match folder after the match ends (tests). Default: delete it.
@export var keep_files: bool = false
## A folder of its own under matches_root (after the flags): two launchers of one machine (two private servers)
## then never share a registry, so neither takes the other's match for a leftover.
@export var matches_subdir: String = ""

var _matches: Dictionary = {}
var _poll_accum: float = 0.0
## Relay ports another host holds (port -> until ms): skipped for a while.
var _busy_ports: Dictionary = {}
## Where the port search starts. Relay ports are virtual and shared by every server of the game on that relay, so
## each launcher starts at a random one (two private servers rarely meet, and if they do the second moves on).
var _search_from: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if runner == null:
		runner = MpProcessRunner.new()
	if config == null:
		config = MpLobbyConfig.new()
	config = config.with_cli_overrides()
	if not matches_subdir.is_empty():
		config.matches_root = config.matches_root.path_join(matches_subdir)
	MpMatchFiles.ensure_dir(config.matches_root)
	if reap_on_ready:
		reap_orphans()


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < config.poll_s:
		return
	_poll_accum = 0.0
	poll()


func active_count() -> int:
	return _matches.size()


func active_ids() -> PackedStringArray:
	return PackedStringArray(_matches.keys())


func pid_of(match_id: String) -> int:
	return int(_matches.get(match_id, {}).get("pid", 0))


func port_of(match_id: String) -> int:
	return int(_matches.get(match_id, {}).get("port", 0))


func is_listening(match_id: String) -> bool:
	return bool(_matches.get(match_id, {}).get("listening", false))


## `ticket`: {world, options, seed, seats: [{slot, token, meta}], ...} (glue content, any keys).
## ERR_BUSY = max_matches reached. ERR_UNAVAILABLE = no free port. ERR_ALREADY_EXISTS = id in use.
func launch(match_id: String, ticket: Dictionary) -> Error:
	if not MpMatchFiles.is_valid_id(match_id):
		return ERR_INVALID_PARAMETER
	if _matches.has(match_id):
		return ERR_ALREADY_EXISTS
	if _matches.size() >= config.max_matches:
		return ERR_BUSY
	var port := _free_port()
	if port == 0:
		return ERR_UNAVAILABLE
	var root := config.matches_root
	MpMatchFiles.remove_dir(MpMatchFiles.dir_of(root, match_id))
	var err := MpMatchFiles.ensure_dir(MpMatchFiles.dir_of(root, match_id))
	if err != OK:
		return err
	var full := ticket.duplicate(true)
	full["match_id"] = match_id
	full["port"] = port
	full["room_pid"] = runner.own_pid()
	full["expires_ms"] = MpMatchFiles.now_ms() + int(config.ticket_ttl_s * 1000.0)
	var seats: Array = []
	for seat in full.get("seats", []):
		var row: Dictionary = (seat as Dictionary).duplicate()
		## A row without a token (a bot seat) has no hash: nobody can be admitted into it.
		if not str(row.get("token", "")).is_empty():
			row["token_sha256"] = MpMatchFiles.sha256(str(row["token"]))
		row.erase("token")
		seats.append(row)
	full["seats"] = seats
	var ticket_path := MpMatchFiles.path_of(root, match_id, MpMatchFiles.TICKET)
	err = MpMatchFiles.write_json(ticket_path, full, true)
	if err != OK:
		return err
	var pid := runner.spawn(
		executable if not executable.is_empty() else OS.get_executable_path(),
		_build_args(match_id, port, ticket_path)
	)
	if pid <= 0:
		MpMatchFiles.remove_dir(MpMatchFiles.dir_of(root, match_id))
		return FAILED
	_matches[match_id] = {
		"pid": pid, "port": port, "started_ms": MpMatchFiles.now_ms(),
		"listening": false, "result_seen_ms": 0,
		## Kept to launch it again on another port if the relay refuses this one.
		"ticket": ticket.duplicate(true),
	}
	_write_registry()
	return OK


## Kills the process and reports `match_failed(reason)`.
func abort(match_id: String, reason: String) -> void:
	if _matches.has(match_id):
		_fail(match_id, reason)


## Kills what is in the registry and still runs (previous run). Returns how many were killed.
## A pid is killed only if its state.json has the same pid and a recent heartbeat, and the live
## command line is this match's dedicated (`--match-ticket-file=<its ticket>`): a reused pid is left alone.
func reap_orphans() -> int:
	var killed := 0
	var root := config.matches_root
	var registry := MpMatchFiles.read_json(MpMatchFiles.registry_path(root))
	var entries: Dictionary = registry.get("matches", {})
	for match_id in entries.keys():
		var pid := int((entries[match_id] as Dictionary).get("pid", 0))
		var state := MpMatchFiles.read_json(MpMatchFiles.path_of(root, str(match_id), MpMatchFiles.STATE))
		var fresh := MpMatchFiles.now_ms() - int(state.get("heartbeat_ms", 0)) <= int(config.reap_heartbeat_max_s * 1000.0)
		if fresh and int(state.get("pid", -1)) == pid and _kill_verified(pid, str(match_id)):
			killed += 1
		if MpMatchFiles.is_valid_id(str(match_id)) and not keep_files:
			MpMatchFiles.remove_dir(MpMatchFiles.dir_of(root, str(match_id)))
	_write_registry()
	return killed


func poll() -> void:
	var now := MpMatchFiles.now_ms()
	for match_id in _matches.keys():
		_poll_match(str(match_id), now)


func _poll_match(match_id: String, now: int) -> void:
	var m: Dictionary = _matches[match_id]
	var root := config.matches_root
	var pid := int(m["pid"])
	var running := runner.is_running(pid)
	var result := MpMatchFiles.read_json(MpMatchFiles.path_of(root, match_id, MpMatchFiles.RESULT))
	if not result.is_empty():
		## The relay refused this port (another live host): the same match on the next free port.
		if str(result.get("reason", "")) == "port_in_use" and not bool(m["listening"]):
			_retry_elsewhere(match_id)
			return
		if not running:
			_finish(match_id, result)
			return
		if int(m["result_seen_ms"]) == 0:
			m["result_seen_ms"] = now
		elif now - int(m["result_seen_ms"]) > int((config.result_quit_delay_s + config.parent_check_s) * 1000.0):
			_kill_verified(pid, match_id)
		return
	if not running:
		_fail(match_id, "exited")
		return
	if now - int(m["started_ms"]) > int(config.match_max_s * 1000.0):
		_fail(match_id, "match_max")
		return
	var state := MpMatchFiles.read_json(MpMatchFiles.path_of(root, match_id, MpMatchFiles.STATE))
	if bool(state.get("listening", false)):
		if not bool(m["listening"]):
			m["listening"] = true
			match_listening.emit(match_id, int(m["port"]))
		if now - int(state.get("heartbeat_ms", now)) > int(config.heartbeat_stale_s * 1000.0):
			_fail(match_id, "heartbeat_stale")
	elif now - int(m["started_ms"]) > int(config.spawn_timeout_s * 1000.0):
		_fail(match_id, "spawn_timeout")


func _finish(match_id: String, result: Dictionary) -> void:
	_release(match_id)
	match_ended.emit(match_id, result)


func _fail(match_id: String, reason: String) -> void:
	var pid := int(_matches[match_id]["pid"])
	_kill_verified(pid, match_id)
	_release(match_id)
	match_failed.emit(match_id, reason)


func _release(match_id: String) -> void:
	_matches.erase(match_id)
	_write_registry()
	if not keep_files:
		MpMatchFiles.remove_dir(MpMatchFiles.dir_of(config.matches_root, match_id))


func _build_args(match_id: String, port: int, ticket_path: String) -> PackedStringArray:
	var args := PackedStringArray(base_args)
	if not log_file_flag.is_empty():
		args.append(log_file_flag)
		args.append(ProjectSettings.globalize_path(MpMatchFiles.path_of(config.matches_root, match_id, MpMatchFiles.LOG)))
	args.append("--")
	args.append_array(agent_args)
	args.append("--mp-port=%d" % port)
	## Through the relay a taken port is answered at once and this launcher moves on (no restart to wait for).
	if MpTransport.normalize(config.transport) == MpTransport.RELAY:
		args.append("--relay-refused-grace-s=0.5")
	args.append("--match-ticket-file=%s" % ticket_path)
	args.append("--room-pid=%d" % runner.own_pid())
	for field in config.agent_fields:
		args.append("%s=%s" % [MpLobbyConfig.flag_for(field), str(config.get(field))])
	return args


## Kills `pid` only if it still is the dedicated of `match_id`. True if it was killed.
func _kill_verified(pid: int, match_id: String) -> bool:
	var needle := "--match-ticket-file=%s" % MpMatchFiles.path_of(config.matches_root, match_id, MpMatchFiles.TICKET)
	if runner.is_running(pid) and runner.command_contains(pid, needle):
		runner.kill(pid)
		return true
	return false


func _free_port() -> int:
	var used := {}
	for m in _matches.values():
		used[int(m["port"])] = true
	var now := MpMatchFiles.now_ms()
	for port in _busy_ports.keys():
		if int(_busy_ports[port]) < now:
			_busy_ports.erase(port)
	var span := config.match_port_max - config.match_port_min + 1
	if _search_from < 0:
		_search_from = randi() % span if MpTransport.normalize(config.transport) == MpTransport.RELAY else 0
	for i in span:
		var port := config.match_port_min + (_search_from + i) % span
		if used.has(port) or _busy_ports.has(port):
			continue
		if MpTransport.port_is_free(config.transport, port):
			return port
	return 0


## The relay turned this match's port away: forget the attempt, keep that port aside for a minute, launch the same
## ticket on another port. The caller only ever sees the match that listens (or fails for another reason).
func _retry_elsewhere(match_id: String) -> void:
	var m: Dictionary = _matches[match_id]
	var ticket: Dictionary = m.get("ticket", {})
	_busy_ports[int(m["port"])] = MpMatchFiles.now_ms() + 60000
	_kill_verified(int(m["pid"]), match_id)
	_matches.erase(match_id)
	MpMatchFiles.remove_dir(MpMatchFiles.dir_of(config.matches_root, match_id))
	var err := launch(match_id, ticket) if not ticket.is_empty() else ERR_UNAVAILABLE
	if err != OK:
		match_failed.emit(match_id, "no_free_port")


func _write_registry() -> void:
	var entries := {}
	for match_id in _matches.keys():
		entries[match_id] = {"pid": _matches[match_id]["pid"], "port": _matches[match_id]["port"]}
	MpMatchFiles.ensure_dir(config.matches_root)
	MpMatchFiles.write_json(
		MpMatchFiles.registry_path(config.matches_root),
		{"launcher_pid": runner.own_pid(), "matches": entries}
	)
