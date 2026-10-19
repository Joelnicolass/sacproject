extends Node

## RFC-049 049e (F294). One headless player of `agent/runs/run_049e.sh`: joins a dedicated started by hand (no room), takes the
## slot the server gives, loads the world it is told to and reads the result from the MatchState the server replicates.
## The main scene only starts a twin of this script under `root`, because loading the world frees the main scene.
## Flags: --e2e-name --mp-port (the kit reads it) --e2e-expect-slot=N (the slot it must get) --e2e-expect-reject (it must NOT get a
## slot: the dedicated has no place for it) --e2e-expect-winners=1,2 (the winner_slots the match must end with)
## --e2e-expect-mode=2v2 (the mode the server sent) --e2e-timeout-s=N (how long to wait for the result, 150 by default) --e2e-linger-s=N (stay connected N seconds after the result,
## so a second client can try the place that is taken; 0 by default).
## Prints `PASS …` / `FAIL …` per check and `E2E CLIENT <name> PASS|FAIL`; exit 0 / 1.

const LOCAL_HOST := "127.0.0.1"
const RUNNER_META := "dedicated_client_runner"
const STEP_S := 40.0

var _name := ""
var _fails := 0
var _finished := false
var _slot := 0
var _rejected := ""


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "DedicatedClientRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_name = MpBoot.user_value("e2e-name", "?")
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	_run.call_deferred()


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
	print("E2E CLIENT %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _state() -> MatchState:
	return get_tree().get_first_node_in_group(&"match_state") as MatchState


func _run() -> void:
	_check(SacrificeFlow.join_lan(LOCAL_HOST) == OK, "%s joins the dedicated" % _name)
	if MpBoot.user_flag("e2e-expect-reject"):
		await get_tree().create_timer(15.0).timeout
		_check(_slot == 0 and _state() == null, "%s is left out: no slot, no world (slot %d)" % [_name, _slot])
		_finish()
		return
	_check(await _until(func() -> bool: return _slot != 0), "%s gets a slot" % _name)
	var want := int(MpBoot.user_value("e2e-expect-slot", "0"))
	if want > 0:
		_check(_slot == want, "%s has slot %d (got %d)" % [_name, want, _slot])
	_check(await _until(func() -> bool: return _state() != null), "%s loaded the match world" % _name)
	var mode_tag := MpBoot.user_value("e2e-expect-mode", "")
	if not mode_tag.is_empty():
		_check(String(GameModeCatalog.current_tag()) == mode_tag, "%s plays the mode %s (got %s)" % [_name, mode_tag, GameModeCatalog.current_tag()])
	var timeout_s := float(MpBoot.user_value("e2e-timeout-s", "150"))
	var state := _state()
	var ended := await _until(func() -> bool: return state != null and state.ended, timeout_s)
	_check(ended, "%s sees the end of the match" % _name)
	if ended:
		print("E2E_RESULT %s winner_slots=%s winner_team=%d defeated=%s" % [_name, str(state.winner_slots), state.winner_team, str(state.defeated_slots)])
		var expect := MpBoot.user_value("e2e-expect-winners", "")
		if not expect.is_empty():
			var winners: Array[int] = []
			for part in expect.split(",", false):
				winners.append(int(part))
			_check(state.winner_slots == winners, "%s: the winners are %s (got %s)" % [_name, str(winners), str(state.winner_slots)])
	var linger := float(MpBoot.user_value("e2e-linger-s", "0"))
	if linger > 0.0:
		await get_tree().create_timer(linger).timeout
	MpKit.leave()
	_finish()
