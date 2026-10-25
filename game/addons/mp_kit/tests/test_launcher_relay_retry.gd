extends "res://addons/mp_kit/tests/mp_test.gd"

## MpMatchLauncher through the relay: a match whose port the relay refused (another live host) is launched again on
## another port, and only the match that listens is reported. No process is started (a fake runner).


class FakeRunner extends MpProcessRunner:
	var next_pid := 50000
	var alive: Dictionary = {}
	var spawned: Array = []

	func spawn(_executable: String, args: PackedStringArray) -> int:
		next_pid += 1
		alive[next_pid] = true
		spawned.append(args)
		return next_pid

	func is_running(pid: int) -> bool:
		return alive.has(pid)

	func command_contains(_pid: int, _needle: String) -> bool:
		return true

	func kill(pid: int) -> void:
		alive.erase(pid)

	func own_pid() -> int:
		return 1


func _port_arg(args: PackedStringArray) -> int:
	for a in args:
		if a.begins_with("--mp-port="):
			return int(a.trim_prefix("--mp-port="))
	return 0


func test_refused_port_moves_on() -> void:
	var config := MpLobbyConfig.new()
	config.transport = "relay"
	config.matches_root = "user://mpkit_test_retry"
	config.match_port_min = 7800
	config.match_port_max = 7803
	var launcher := MpMatchLauncher.new()
	launcher.config = config
	launcher.reap_on_ready = false
	var runner := FakeRunner.new()
	launcher.runner = runner
	tree.root.add_child(launcher)
	var failed: Array = []
	var listening: Array = []
	launcher.match_failed.connect(func(id: String, reason: String) -> void: failed.append(reason))
	launcher.match_listening.connect(func(id: String, port: int) -> void: listening.append(port))
	check(launcher.launch("m1", {"seats": [{"slot": 1, "token": "abc"}]}) == OK, "the match is launched")
	var first := launcher.port_of("m1")
	var root := launcher.config.matches_root
	MpMatchFiles.write_json(MpMatchFiles.path_of(root, "m1", MpMatchFiles.RESULT), {"reason": "port_in_use"})
	launcher.poll()
	var second := launcher.port_of("m1")
	check(second != 0 and second != first, "refused on %d, launched again on %d" % [first, second])
	check(runner.spawned.size() == 2 and _port_arg(runner.spawned[1]) == second, "a new process for the new port")
	check(failed.is_empty(), "the caller never saw the refused attempt")
	var ticket := MpMatchFiles.read_json(MpMatchFiles.path_of(root, "m1", MpMatchFiles.TICKET))
	check(int(ticket.get("port", 0)) == second and str(ticket["seats"][0].get("token_sha256", "")) == MpMatchFiles.sha256("abc"), "the new ticket has the new port and the same seats")
	MpMatchFiles.write_json(MpMatchFiles.path_of(root, "m1", MpMatchFiles.STATE), {"listening": true, "heartbeat_ms": MpMatchFiles.now_ms()})
	launcher.poll()
	check(listening == [second], "only the match that listens is announced")
	launcher.abort("m1", "done")
	launcher.queue_free()
	MpMatchFiles.remove_dir(root)
