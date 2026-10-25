extends Node

## Lab-only player robot for the arena_2d example. Inert without `--probe=`. It presses keys like a person and checks
## what comes back over the network, printing `PASS …` / `FAIL …` and a last `PROBE <role> PASS|FAIL` line.
## Roles: solo | client (the first player) | late (joins after the first one played) | watch (server or host:
## waits for a remote player to move and score). `--probe-linger-s=N` keeps a passing process alive N seconds.

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
