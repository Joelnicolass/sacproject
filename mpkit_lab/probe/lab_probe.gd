extends Node

## Lab-only player robot for the arena_2d example. Inert without `--probe=`. It presses keys like a person and checks
## what comes back over the network, printing `PASS …` / `FAIL …` and a last `PROBE <role> PASS|FAIL` line.
## Roles: solo | client (the first player) | basic (any game: move and score only, e.g. one the wizard wrote) | late (joins after the first one played) | watch (server or host:
## waits for a remote player to move and score) | lag (own player under a bad network: response and corrections) |
## observe (another player, `--probe-watch-slot=N`: how evenly it moves on screen) | lobby (online rooms through the
## lobby screen: `--probe-lobby=host:port --probe-name=X`, `--probe-create=Room` makes the room and scores to win) |
## private (MpLocalServer on this PC; writes "port code" to `--probe-code-file`, plays and wins) | invited (joins
## with "ip:port#CODE" from that file) | badcode (same address, a wrong code: must be turned away) | flood (sends 500
## tunnel messages and 500 to_server calls at once) | floodwatch (server: only what the limits allow gets through). `--probe-linger-s=N` keeps a
## passing process alive N seconds. lag and observe print `METRIC name=value` lines.

## Seconds each check may wait (`--probe-timeout-s=N` for a person opening a browser by hand).
var step_timeout_s := 20.0

var _role := ""
var _fails := 0
## What the network told this process (session cases read them).
var _join_failed := false
var _server_lost := false
var _rejected := ""
## Stand-in while the current scene has no MpState (between scenes).
var _empty_state: MpState


func _ready() -> void:
	_role = MpBoot.user_value("probe", "")
	step_timeout_s = float(MpBoot.user_value("probe-timeout-s", "20"))
	MpKit.join_failed.connect(func() -> void: _join_failed = true)
	MpKit.server_lost.connect(func() -> void: _server_lost = true)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
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
		"basic":
			await _until(_networked_slot, "the server gave this client a slot")
			await _play_basic(MpKit.local_slot())
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
		"flood":
			await _flood()
		"failjoin":
			await _check_fail_join()
		"refused":
			await _check_refused()
		"leaver":
			await _leave_and_return()
		"rejoinwatch":
			await _watch_leave_and_return()
		"lost":
			await _check_server_lost()
		"browse":
			await _browse_lan()
		"floodwatch":
			await _watch_flood()
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
	var shots := get_tree().current_scene.get_node("Projectiles")
	await _tap(&"ui_select")
	await _until(func() -> bool: return shots.get_child_count() > 0, "a shot the server spawned (spawn_actor) reached this peer")
	await _until(func() -> bool: return shots.get_child_count() == 0, "the shot was removed everywhere (despawn)")
	var bell := get_tree().get_first_node_in_group(&"bell")
	await _tap(&"ui_cancel")
	await _until(func() -> bool: return bell.rings == 1, "the bell (no owner) rang through to_server")
	await _until(func() -> bool: return int(_state().get_value(&"bell_by", -1)) == _who_rang(slot), "the server knew who rang it (sender_slot)")


## Only what every MpKit game has: the arrows move the own player (server simulated) and Enter scores.
func _play_basic(slot: int) -> void:
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	var start_x: float = pawn.position.x
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return pawn.position.x > start_x + 1.0, "P%d moved right" % slot)
	Input.action_release(&"ui_right")
	await _tap(&"ui_accept")
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) == 1, "the score reached 1")


## The slot that rang the bell: the player, or 1 in solo / for the host (local_slot of the authority).
func _who_rang(slot: int) -> int:
	return slot


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
	var bell := get_tree().get_first_node_in_group(&"bell")
	await _until(func() -> bool: return bell.rings == 1, "the bell rung before joining shows (a static actor, late join)")
	_check(get_tree().current_scene.get_node("Projectiles").get_child_count() == 0, "no leftover shots reached the late peer")
	## Bypass the client-side guard: send the RPC by hand for an actor this peer does not own.
	var their := MpActor.of(first)
	their.rpc_server_call.rpc_id(1, &"recolor", [])
	await get_tree().create_timer(1.0).timeout
	_check(first.color_index == 1, "the server refused a to_server call from a peer that does not own the actor")


## Server or host: a remote player's input moves its pawn here and its score counts here.
func _check_watch() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var slot := 2 if MpKit.is_listen_host() else 1
	var pawn := await _pawn(slot)
	if pawn == null:
		return
	if MpBoot.user_flag("probe-server-node"):
		## A server-only node added by hand in a spawn_path (an effect the engine does not replicate): clients must not
		## be affected (no gate, nothing held for it).
		var fx := Node2D.new()
		fx.name = "ServerOnlyFx"
		get_tree().current_scene.get_node("Projectiles").add_child(fx)
		_check(fx.get_node_or_null(MpSpawner.GATE_NAME) == null, "a server-only node in spawn_path got no gate")
	var start_x: float = pawn.position.x
	var min_move := float(MpBoot.user_value("probe-min-move", "60"))
	await _until(func() -> bool: return pawn.position.x > start_x + min_move, "the remote P%d input moved it on the server" % slot)
	await _until(func() -> bool: return int(_state().get_value(StringName("p%d" % slot), 0)) >= 1, "the remote P%d scored on the server" % slot)
	if pawn.has_node("MpInput") and MpBoot.user_value("probe-min-move", "60") == "60":
		await _until(func() -> bool: return pawn.get_node("MpInput").get_value(&"aim") is Vector2, "the owner's aim (MpInput.set_value) reached the server")


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
	## Robust spread: median of |speed - median| / median. Jitter on every frame raises it; one stall of a process
	## (the walker paused, then caught up: correct behaviour) does not. cv shows both.
	var sorted := Array(speeds)
	sorted.sort()
	var median: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
	var deviations := sorted.map(func(v: float) -> float: return absf(v - median))
	deviations.sort()
	var mad: float = deviations[deviations.size() / 2] / maxf(median, 0.001) if not deviations.is_empty() else 1.0
	print("METRIC proxy_speed_px_s=%.1f proxy_speed_median=%.1f proxy_speed_mad=%.3f proxy_speed_cv=%.3f frames=%d" % [mean, median, mad, cv, speeds.size()])
	_check(median > 150.0, "P%d moved at about its real speed on screen" % slot)
	_check(mad < float(MpBoot.user_value("probe-max-mad", "0.05")), "its on-screen speed was steady frame to frame (low jitter)")


## The whole online path as a person does it, through MpLobbyScreen's buttons: connect, create or join, ready, play
## the match the room server starts, and come back to the lobby with the result. Options:
##   --probe-create=Room [--probe-private]       make the room (private: its code goes to --probe-code-file)
##   --probe-join-room=Room | --probe-join-code   join by name from the list, or with the code from the file
##   --probe-chat=text / --probe-expect-chat=text say something / wait to read it
##   --probe-leave-room-once                      leave the room once after sitting, and come back
##   --probe-drop=rejoin|abandon                  in the match: leave it, and come back with the same ticket (or not)
##   --probe-delay-join-s=N                       join the match N seconds after the room server started it
##   --probe-check-paused                         the world must not move until every seat loaded
##   --probe-score=N (default 3 for the creator, 0 for the rest)  points this player scores (3 wins)
##   --probe-hold-s=N                             stay in the match N seconds before scoring
##   --probe-expect-back=N                        wait for MpState back_N before scoring
##   --probe-expect-error=code                    the lobby must answer this error instead of a match
##   --probe-expect-result=key:value              the room's result must have it (default winner present)
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
	var errors: Array[String] = []
	client.error_received.connect(func(code: String) -> void: errors.append(code))
	var chat: Array[String] = []
	client.chat_received.connect(func(_seat: int, _who: String, text: String) -> void: chat.append(text))
	var delay := float(MpBoot.user_value("probe-delay-join-s", "0"))
	if delay > 0.0:
		screen.auto_join_match = false
		screen.match_found.connect(func(_h: String, _p: int, _t: String) -> void:
			await get_tree().create_timer(delay).timeout
			screen.join_found())
	screen.connect_lobby(MpBoot.user_value("probe-lobby", "127.0.0.1:7700"), MpBoot.user_value("probe-name", "Bot"))
	if not await _until(client.is_online, "connected to the lobby"):
		return
	await _enter_room(screen, client)
	if client.my_seat() < 0:
		return
	if MpBoot.user_flag("probe-leave-room-once"):
		screen.leave_room()
		await _until(func() -> bool: return client.my_seat() < 0, "left the room (back to the list)")
		await _enter_room(screen, client)
	var say := MpBoot.user_value("probe-chat", "")
	if not say.is_empty():
		await _until(func() -> bool: return _seated(client) >= 2, "the room is full before chatting")
		screen.send_chat(say)
	var expect_chat := MpBoot.user_value("probe-expect-chat", "")
	if not expect_chat.is_empty():
		await _until(func() -> bool: return chat.has(expect_chat), "the chat line arrived (%s)" % expect_chat)
	screen.set_ready(true)
	var expect_error := MpBoot.user_value("probe-expect-error", "")
	if not expect_error.is_empty():
		await _until(func() -> bool: return errors.has(expect_error), "the lobby answered %s" % expect_error)
		return
	await _until(_networked_slot, "the room server started the match and this client got in")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	if MpBoot.user_flag("probe-check-paused"):
		var start_x: float = pawn.position.x
		Input.action_press(&"ui_right")
		await get_tree().create_timer(1.0).timeout
		_check(absf(pawn.position.x - start_x) < 1.0, "the world waits (paused) until every seat loaded")
		var leave_buttons := get_tree().current_scene.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return b is MpLeaveButton)
		_check(not leave_buttons.is_empty() and (leave_buttons[0] as Node).can_process(), "the Leave button works while the world waits")
		Input.action_release(&"ui_right")
		await _pawn(2 if MpKit.local_slot() == 1 else 1)
		Input.action_press(&"ui_right")
		await _until(func() -> bool: return is_instance_valid(pawn) and pawn.position.x > start_x + 20.0, "once everyone loaded the match runs")
		Input.action_release(&"ui_right")
	var drop := MpBoot.user_value("probe-drop", "")
	if not drop.is_empty():
		await get_tree().create_timer(0.5).timeout
		MpKit.leave()
		_check(not MpKit.is_networked(), "left the match on purpose")
		if drop == "abandon":
			return
		## What a dropped connection does (MpKit emits server_lost): the flow takes the player back to the lobby,
		## which offers "Back to the match".
		MpKit.server_lost.emit()
		var back_screens: Array[MpLobbyScreen] = []
		await _until(func() -> bool:
			if get_tree().current_scene is MpLobbyScreen:
				back_screens.append(get_tree().current_scene)
			return not back_screens.is_empty(), "after the drop the player is back in the lobby")
		if back_screens.is_empty():
			return
		await _until(func() -> bool: return back_screens[0].can_rejoin(), "the lobby offers Back to the match")
		back_screens[0].rejoin_match()
		await _until(_networked_slot, "came back to the match with the same ticket")
		await _pawn(MpKit.local_slot())
	var back := MpBoot.user_value("probe-expect-back", "")
	if not back.is_empty():
		await _until(func() -> bool: return int(_state().get_value(StringName("back_%s" % back), 0)) >= 1, "the match saw P%s come back (player_back)" % back)
	await get_tree().create_timer(float(MpBoot.user_value("probe-hold-s", "0"))).timeout
	var creator := not MpBoot.user_value("probe-create", "").is_empty()
	## Like a person: score once the match runs (MpMatch keeps the world paused until every seat loaded, and a key
	## pressed while paused does nothing).
	await _until(func() -> bool:
		var match_node := get_tree().current_scene.get_node_or_null("Match") as MpMatch
		return match_node != null and not match_node.waiting, "the match runs (every seat loaded)")
	for i in int(MpBoot.user_value("probe-score", "3" if creator else "0")):
		await _tap(&"ui_accept")
		await get_tree().create_timer(0.2).timeout
	await _until(func() -> bool: return get_tree().current_scene is MpLobbyScreen, "back in the lobby after the match")
	var want := MpBoot.user_value("probe-expect-result", "winner")
	await _until(func() -> bool:
		var result: Variant = client.room.get("last_result", {})
		if not result is Dictionary:
			return false
		var key := want.get_slice(":", 0)
		if not (result as Dictionary).has(key):
			return false
		return want.count(":") == 0 or str((result as Dictionary)[key]) == want.get_slice(":", 1), "the room shows the match result (%s)" % want)
	print("METRIC result=%s" % JSON.stringify(client.room.get("last_result", {})))


## Create or join a room the way the options say, and take a seat.
func _enter_room(screen: MpLobbyScreen, client: MpLobbyClient) -> void:
	var room_name := MpBoot.user_value("probe-create", "")
	var code_file := MpBoot.user_value("probe-code-file", "user://probe_room_code.txt")
	if not room_name.is_empty() and client.room.is_empty():
		screen.create_room(room_name, MpBoot.user_flag("probe-private"))
		await _until(func() -> bool: return client.my_seat() >= 0, "took a seat")
		if MpBoot.user_flag("probe-private"):
			await _until(func() -> bool: return client.room.has("code"), "the private room has a code")
			var f := FileAccess.open(code_file, FileAccess.WRITE)
			f.store_string(str(client.room["code"]))
			f.close()
		return
	if MpBoot.user_flag("probe-join-code"):
		await _until(func() -> bool: return FileAccess.file_exists(code_file), "the room's code was published")
		screen.join_code(FileAccess.get_file_as_string(code_file).to_lower())
	else:
		var wanted := MpBoot.user_value("probe-join-room", "")
		if not await _until(func() -> bool: return _listed_index(client, wanted) >= 0, "the room shows in the list"):
			return
		screen.join_room(str(client.rooms[_listed_index(client, wanted)]["id"]))
	await _until(func() -> bool: return client.my_seat() >= 0, "took a seat")


func _listed_index(client: MpLobbyClient, room_name: String) -> int:
	for i in client.rooms.size():
		if room_name.is_empty() or str(client.rooms[i]["name"]) == room_name:
			return i
	return -1


func _seated(client: MpLobbyClient) -> int:
	var n := 0
	for seat: Dictionary in client.room.get("seats", []):
		if not bool(seat["free"]):
			n += 1
	return n


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


## Joining an address nobody serves fails cleanly: the failure is reported and the menu still plays solo.
func _check_fail_join() -> void:
	await _until(func() -> bool: return _join_failed or _server_lost, "joining a dead address is reported as failed")
	await _until(func() -> bool: return not MpKit.is_networked(), "after the failure this process is offline again")
	MpFlow.find_in_tree(self).play_solo()
	await _pawn(1)


## A peer the server turns away (full, wrong transport) never gets a slot and ends offline.
func _check_refused() -> void:
	var waited := Time.get_ticks_msec()
	await _until(func() -> bool: return _join_failed or _server_lost or _rejected != "" or Time.get_ticks_msec() - waited > 6000, "the connection ended or timed out")
	_check(not (MpKit.is_networked() and MpKit.has_local_slot()), "the refused peer never got a slot")
	await _until(func() -> bool: return not MpKit.is_networked() or Time.get_ticks_msec() - waited > 15000, "the refused peer ends offline (or still waiting, harmless)")


## Leave to the menu (the Leave button) and come back: a new pawn, the server forgot the old one.
func _leave_and_return() -> void:
	await _until(_networked_slot, "the leaver got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	var flow := MpFlow.find_in_tree(self)
	flow.return_to_boot()
	await _until(func() -> bool: return get_tree().current_scene.name == "Boot" and not MpKit.is_networked(), "Leave goes back to the menu, offline")
	await get_tree().create_timer(1.0).timeout
	flow.join_address("127.0.0.1:%s" % MpBoot.user_value("mp-port", "7777"))
	await _until(_networked_slot, "joining again gets a slot")
	await _pawn(MpKit.local_slot())


## Server side of the leaver: the pawn goes when its player leaves and comes back when it joins again.
func _watch_leave_and_return() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	await _pawn(1)
	await _until(func() -> bool: return get_tree().current_scene.get_node_or_null("Actors/Pawn_1") == null, "the pawn of a player who left is removed")
	await _pawn(1)


## The server goes away: the client is told and lands on the menu.
func _check_server_lost() -> void:
	await _until(_networked_slot, "the client got a slot")
	await _pawn(MpKit.local_slot())
	print("READY for the server to go")
	await _until(func() -> bool: return _server_lost, "the client noticed the server went away")
	await _until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Boot", "and is back on the menu")


## A listen host advertises on the LAN; this client finds it in the boot menu's list and joins from there.
func _browse_lan() -> void:
	var menus: Array[MpBootMenu] = []
	await _until(func() -> bool:
		var found := get_tree().get_nodes_in_group(MpBootMenu.GROUP)
		if not found.is_empty():
			menus.append(found[0])
		return not menus.is_empty(), "the boot menu is up")
	if menus.is_empty():
		return
	var menu := menus[0]
	if not await _until(func() -> bool: return not menu.lan_rooms().is_empty(), "the menu's LAN list shows the host (MpLan)"):
		return
	menu.join_lan_room(0)
	await _until(_networked_slot, "joining from the LAN list gets a slot")
	await _pawn(MpKit.local_slot())


func _flood() -> void:
	await _until(_networked_slot, "the flooding client got a slot")
	var pawn := await _pawn(MpKit.local_slot())
	if pawn == null:
		return
	var net := MpActor.of(pawn)
	for i in 500:
		MpKit.send_custom(&"spam", {"i": i})
		net.to_server(&"recolor")
	print("PASS sent 500 tunnel messages and 500 server calls")


func _watch_flood() -> void:
	await _until(func() -> bool: return MpKit.is_server(), "this process is the server")
	var got: Array[int] = [0]
	MpKit.custom_received.connect(func(_c: StringName, _d: Dictionary, from_peer: int) -> void:
		if from_peer != 1:
			got[0] += 1)
	var pawn := await _pawn(1)
	if pawn == null:
		return
	await _until(func() -> bool: return got[0] > 0, "the first tunnel messages arrived")
	await get_tree().create_timer(2.0).timeout
	print("METRIC tunnel_accepted=%d server_calls_accepted=%d (of 500 each)" % [got[0], pawn.color_index])
	_check(got[0] >= 50 and got[0] <= 60 + 30 * 4, "the tunnel let the burst in and dropped the flood")
	_check(pawn.color_index >= 100 and pawn.color_index <= 120 + 60 * 4, "to_server let the burst in and dropped the flood")


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
	var state := MpState.of(get_tree().current_scene)
	if state == null and _empty_state == null:
		_empty_state = MpState.new()
	return state if state else _empty_state


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
