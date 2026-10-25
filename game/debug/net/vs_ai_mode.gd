extends Node

## RFC-049 049e (F294). «Contra la IA» with a mode, headless: `SacrificeFlow.play_vs_ai()` with `--mode=2v2 --map=test_flat4` puts an AI
## in every seat but the player's. Checks the seats it asks for (slots 2..seats), that each one is seated (`AiRoster.sides`) and that
## the player's team is the player + the AI of slot 2 against slots 3 and 4. The main scene only starts a twin under `root`,
## because loading the world frees the main scene.
## `--headless --fixed-fps 60 res://debug/net/vs_ai_mode.tscn -- --mode=2v2 --map=test_flat4 [--e2e-seats=4]`. Prints VS_AI_MODE PASS / FAIL.

const RUNNER_META := "vs_ai_mode_runner"
var _fails := 0


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "VsAiModeRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _until(cond: Callable, timeout_s: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _roster() -> AiRoster:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("%AiRoster") as AiRoster if scene != null else null


func _run() -> void:
	var seats := int(MpBoot.user_value("e2e-seats", "4"))
	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = 120.0
	timeout.timeout.connect(func() -> void:
		print("VS_AI_MODE FAIL: global timeout")
		get_tree().quit(1))
	add_child(timeout)
	timeout.start()
	SacrificeFlow.play_vs_ai(null, null)
	var slots: Array[int] = []
	for seat: AiSeat in SacrificeFlow.solo_ai_seats:
		slots.append(seat.slot)
	var expected: Array[int] = []
	for slot in range(2, seats + 1):
		expected.append(slot)
	_check(slots == expected, "the AI seats are the slots %s (got %s)" % [str(expected), str(slots)])
	_check(GameModeCatalog.active().seats() == seats, "the mode has %d seats" % seats)
	_check(await _until(func() -> bool: return _roster() != null and _roster().sides.size() == expected.size(), 60.0), "every AI seat is seated by the roster")
	print("VS_AI_MODE slots=%s sides=%s" % [str(slots), str(_roster().sides.keys()) if _roster() != null else "[]"])
	if seats == 4:
		_check(SideRelations.stance(1, 2) == SideRelations.Stance.ALLY, "slot 2 (AI) is the ally of the player")
		_check(SideRelations.stance(1, 3) == SideRelations.Stance.ENEMY and SideRelations.stance(1, 4) == SideRelations.Stance.ENEMY, "slots 3 and 4 are foes")
	print("VS_AI_MODE PASS" if _fails == 0 else "VS_AI_MODE FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
