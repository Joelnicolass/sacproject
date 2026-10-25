extends Node

## Lab-only player robot for the arena_2d example. Inert without `--probe=`. It presses keys like a person and checks
## what comes back over the network, printing `PASS …` / `FAIL …` and a last `PROBE <role> PASS|FAIL` line.
## Roles: solo | client (the first player) | late (joins after the first one played) | watch (server or host:
## waits for a remote player to move and score) | lag (own player under a bad network: response and corrections) |
## observe (another player, `--probe-watch-slot=N`: how evenly it moves on screen) | lobby (online rooms through the
## lobby screen: `--probe-lobby=host:port --probe-name=X`, `--probe-create=Room` makes the room and scores to win) |
## private (MpLocalServer on this PC; writes "port code" to `--probe-code-file`, plays and wins) | invited (joins
## with "ip:port#CODE" from that file) | badcode (same address, a wrong code: must be turned away). `--probe-linger-s=N` keeps a
## passing process alive N seconds. lag and observe print `METRIC name=value` lines.

## Seconds each check may wait (`--probe-timeout-s=N` for a person opening a browser by hand).
var step_timeout_s := 20.0

var _role := ""
var _fails := 0


func _ready() -> void:
	_role = MpBoot.user_value("probe", "")
	step_timeout_s = float(MpBoot.user_value("probe-timeout-s", "20"))
	if _role.is_empty():
		return
	print("probe %s start" % _role)
	_run.call_deferred()


func _run() -> void:
	## `--probe-join=host:port`: join the way a person does, through the address field of the flow.
	var address := MpBoot.user_value("probe-join", "")
	if not address.is_empty():
		await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
		_check(MpFlow.find_in_tree(self).join_address(address) == OK, "join_address(%s) started" % address)
	match _role:
		"solo":
			await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
			MpFlow.find_in_tree(self).play_solo()
			await _play_as(1)
		"client":
			await _until(_networked_slot, "the server gave this client a slot")
			await _play_as(MpKit.local_slot())
		"late":
			await _check_late()
		"watch":
			await _check_watch()
		"lag":
			await _measure_own_lag()
		"observe":
			await _measure_proxy_jitter()
		"lobby":
			await _play_online()
		"private":
			await _host_private()
		"invited":
			await _join_private(true)
		"badcode":
			await _join_private(false)
		_:
			_check(false, "known role %s" % _role)
	print("PROBE %s %s" % [_role, "PASS" if _fails == 0 else "FAIL"])
	var linger := float(MpBoot.user_value("probe-linger-s", "0"))
	if _fails == 0 and linger > 0.0:
		await get_tree().create_timer(linger).timeout
	get_tree().quit(0 if _fails == 0 else 1)


## Move right, score once, recolor once; every result must come back from the server.
func _play_as(slot: int) -> void:
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return pawn.position.x > start_x + 60.0, "P%d moved right (server simulated, synced back)" % slot)
	Input.action_release(&"ui_right")
	await _tap(&"ui_accept")
	var key := StringName("p%d" % slot)
	await _until(func() -> bool: return int(_state().get_value(key, 0)) == 1, "score %s reached 1 (MpState)" % key)
	await _until(func() -> bool: return pawn.flashes == 1, "the flash event arrived (to_all)")
	await _tap(&"ui_focus_next")
	await _until(func() -> bool: return pawn.color_index == 1, "recolor went to the server and back (to_server + sync)")


## A player who joins after the first one played (`--probe-first=N`, default 1) sees it where it went, its score
## and its color.
func _check_late() -> void:
	var slot := int(MpBoot.user_value("probe-first", "1"))
	await _until(_networked_slot, "the late client got a slot")
	var own := await _pawn(MpKit.local_slot())
	var first := await _pawn(slot)
	if own == null or first == null:
		return
	var marker_x: float = get_tree().current_scene.get_node("SpawnPoints/P%d" % slot).position.x
	await _until(func() -> bool: return first.position.x > marker_x + 50.0, "P%d shows where it moved before this client joined" % slot)
	var key := StringName("p%d" % slot)
	await _until(func() -> bool: return int(_state().get_value(key, 0)) == 1, "the score made before joining arrived")
	await _until(func() -> bool: return first.color_index == 1, "P%d's color made before joining arrived" % slot)


## Server or host: a remote player's input moves its pawn here and its score counts here.
func _check_watch() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var slot := 2 if MpKit.is_listen_host() else 1
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	await _until(func() -> bool: return pawn.position.x > start_x + 60.0, "the remote P%d input moved it on the server" % slot)
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) >= 1, "the remote P%d scored on the server" % slot)


## Own player, predicted: it must answer the key on the next ticks whatever the lag, and the server's corrections
## must stay small while it walks.
func _measure_own_lag() -> void:
	await _until(_networked_slot, "the lag client got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	await get_tree().create_timer(1.0).timeout
	var net := MpActor.of(pawn)
	var start_x: float = pawn.position.x
	Input.action_press(&"ui_left")
	var frames := 0
	while pawn.position.x == start_x and frames < 120:
		await get_tree().physics_frame
		frames += 1
	print("METRIC response_ticks=%d" % frames)
	_check(frames <= 2, "the own player answered the key within 2 ticks (prediction)")
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	var end := t0 + 2000
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		worst = maxf(worst, net.last_correction())
	Input.action_release(&"ui_left")
	await get_tree().create_timer(1.0).timeout
	print("METRIC max_correction_px=%.2f settled_correction_px=%.2f" % [worst, net.last_correction()])
	_check(worst < float(MpBoot.user_value("probe-max-correction", "2")), "server corrections stayed small while walking")
	_check(net.last_correction() < 0.5, "once stopped, the prediction and the server agree")


## Another player walking at a steady speed must look steady here: low spread of its on-screen speed.
func _measure_proxy_jitter() -> void:
	var slot := int(MpBoot.user_value("probe-watch-slot", "2"))
	await _until(_networked_slot, "the observer got a slot")
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	await _until(func() -> bool: return absf(pawn.position.x - start_x) > 20.0, "P%d started walking" % slot)
	await get_tree().create_timer(0.3).timeout
	## Sample after MpActor drew this frame (higher process_priority), with this frame's time.
	var sampler := _Sampler.new()
	sampler.target = pawn
	sampler.process_priority = 20000
	add_child(sampler)
	await get_tree().create_timer(1.0).timeout
	sampler.queue_free()
	var speeds := PackedFloat64Array()
	for i in range(1, sampler.xs.size()):
		var dt := (sampler.ts[i] - sampler.ts[i - 1]) / 1000000.0
		if dt > 0.0:
			speeds.append(absf(sampler.xs[i] - sampler.xs[i - 1]) / dt)
	var mean := 0.0
	for v in speeds:
		mean += v
	mean /= maxf(speeds.size(), 1)
	var spread := 0.0
	for v in speeds:
		spread += (v - mean) * (v - mean)
	var cv := sqrt(spread / maxf(speeds.size(), 1)) / maxf(mean, 0.001)
	print("METRIC proxy_speed_px_s=%.1f proxy_speed_cv=%.3f frames=%d" % [mean, cv, speeds.size()])
	_check(mean > 150.0, "P%d moved at about its real speed on screen" % slot)
	_check(cv < float(MpBoot.user_value("probe-max-cv", "0.1")), "its on-screen speed was steady (low jitter)")


## The whole online path as a person does it, through MpLobbyScreen's buttons: connect, create or join, ready, play
## the match the room server starts, and come back to the lobby with the result.
func _play_online() -> void:
	var flow_ok := await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	if not flow_ok:
		return
	get_tree().change_scene_to_file(MpFlow.find_in_tree(self).lobby_path)
	var screens: Array[MpLobbyScreen] = []
	await _until(func() -> bool:
		if get_tree().current_scene is MpLobbyScreen:
			screens.append(get_tree().current_scene)
		return not screens.is_empty(), "the lobby screen opened")
	if screens.is_empty():
		return
	var screen := screens[0]
	await get_tree().process_frame
	_check(MpFlow.find_in_tree(self) != null, "the flow survived the scene change (it lives under the root)")
	var client := MpLobbyLink.client(get_tree())
	screen.connect_lobby(MpBoot.user_value("probe-lobby", "127.0.0.1:7700"), MpBoot.user_value("probe-name", "Bot"))
	await _until(client.is_online, "connected to the lobby")
	var room_name := MpBoot.user_value("probe-create", "")
	if not room_name.is_empty():
		screen.create_room(room_name)
	else:
		await _until(func() -> bool: return not screen.listed_rooms().is_empty(), "a room shows in the list")
		screen.join_listed(0)
	await _until(func() -> bool: return client.my_seat() >= 0, "took a seat")
	screen.set_ready(true)
	await _until(_networked_slot, "the room server started the match and this client got in")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	if not room_name.is_empty():
		for i in 3:
			await _tap(&"ui_accept")
			await get_tree().create_timer(0.2).timeout
	await _until(func() -> bool: return get_tree().current_scene is MpLobbyScreen, "back in the lobby after the match")
	await _until(func() -> bool:
		var result: Variant = client.room.get("last_result", {})
		return result is Dictionary and (result as Dictionary).has("winner"), "the room shows the match result (winner)")
	print("METRIC result=%s" % JSON.stringify(client.room.get("last_result", {})))


func _host_private() -> void:
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var server := MpLocalServer.start_on(get_tree(), 2)
	var info: Array = []
	server.server_ready.connect(func(_address: String, p_port: int, codes: Dictionary) -> void: info.append([p_port, codes[2]]))
	if not await _until(func() -> bool: return not info.is_empty(), "the private match process listens"):
		return
	var f := FileAccess.open(MpBoot.user_value("probe-code-file", "user://probe_code.txt"), FileAccess.WRITE)
	f.store_string("%d %s" % info[0])
	f.close()
	await _until(_networked_slot, "the host joined its own private match")
	var other := await _pawn(2)
	if other == null:
		return
	for i in 3:
		await _tap(&"ui_accept")
		await get_tree().create_timer(0.2).timeout
	await _until(func() -> bool: return not MpKit.is_networked(), "after the win the host left the match")
	await _until(func() -> bool: return get_tree().root.get_node_or_null("MpLocalServer") == null, "the private server cleaned up")


func _join_private(right_code: bool) -> void:
	var path := MpBoot.user_value("probe-code-file", "user://probe_code.txt")
	if not await _until(func() -> bool: return FileAccess.file_exists(path), "the host published its code"):
		return
	var parts := FileAccess.get_file_as_string(path).split(" ")
	var code := parts[1] if right_code else "WRONG9"
	var rejected: Array = []
	MpKit.admission_rejected.connect(func(reason: String) -> void: rejected.append(reason))
	await _until(func() -> bool: return MpFlow.find_in_tree(self) != null, "the boot scene has a flow")
	var flow := MpFlow.find_in_tree(self)
	var finished: Array = []
	flow.match_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	flow.join_address("127.0.0.1:%s#%s" % [parts[0], code.to_lower()])
	if not right_code:
		await _until(func() -> bool: return not rejected.is_empty(), "a wrong code is turned away")
		return
	await _until(_networked_slot, "the friend got in with the code (typed in lower case)")
	await _pawn(2)
	await _until(func() -> bool: return not finished.is_empty(), "the friend saw the match end")


func _pawn(slot: int) -> Node:
	var found: Array[Node] = []
	var ok := await _until(func() -> bool:
		var scene := get_tree().current_scene
		var node := scene.get_node_or_null("Actors/Pawn_%d" % slot) if scene else null
		if node:
			found.append(node)
		return node != null, "P%d exists here" % slot)
	return found[0] if ok else null


func _networked_slot() -> bool:
	return MpKit.is_networked() and not MpKit.is_server() and MpKit.has_local_slot()


func _state() -> MpState:
	return MpState.of(get_tree().current_scene)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	for i in 3:
		await get_tree().physics_frame
	Input.action_release(action)


func _until(cond: Callable, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(step_timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if get_tree().current_scene != null and cond.call():
			_check(true, what)
			return true
		await get_tree().process_frame
	_check(false, what)
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


class _Sampler extends Node:
	var target: Node2D
	var xs := PackedFloat64Array()
	var ts := PackedInt64Array()

	func _process(_delta: float) -> void:
		xs.append(target.position.x)
		ts.append(Time.get_ticks_usec())
