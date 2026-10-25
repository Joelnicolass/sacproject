extends Node

## Lab-only player robot for the arena_2d example. Inert without `--probe=`. It presses keys like a person and checks
## what comes back over the network, printing `PASS …` / `FAIL …` and a last `PROBE <role> PASS|FAIL` line.
## Roles: solo | client (the first player) | late (joins after the first one played) | watch (server or host:
## waits for a remote player to move and score) | lag (own player under a bad network: response and corrections) |
## observe (another player, `--probe-watch-slot=N`: how evenly it moves on screen). `--probe-linger-s=N` keeps a
## passing process alive N seconds. lag and observe print `METRIC name=value` lines.

const STEP_TIMEOUT_S := 20.0

var _role := ""
var _fails := 0


func _ready() -> void:
	_role = MpBoot.user_value("probe", "")
	if _role.is_empty():
		return
	print("probe %s start" % _role)
	_run.call_deferred()


func _run() -> void:
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
	var end := Time.get_ticks_msec() + int(STEP_TIMEOUT_S * 1000.0)
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
