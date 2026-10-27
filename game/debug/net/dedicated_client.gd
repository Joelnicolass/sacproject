extends Node

## RFC-049 049e (F294), RFC-068 (F392). One headless player of `agent/runs/run_049e.sh` and `run_068_gate.sh`: joins a dedicated
## started by hand or a listen host (no room) through `SacrificeFlow.join_lan`, takes the slot the server gives, loads the world it
## is told to and reads the result from the MatchState the server replicates.
## The main scene only starts a twin of this script under `root`, because loading the world frees the main scene.
## Flags: --e2e-name --mp-port (the kit reads it) --e2e-expect-slot=N (the slot it must get) --e2e-expect-winners=1,2 (the
## winner_slots the match must end with) --e2e-expect-mode=2v2 (the mode the server sent) --e2e-timeout-s=N (how long to wait for
## the result, 150 by default) --e2e-linger-s=N (stay connected N seconds after the result, so a second client can try the place
## that is taken; 0 by default).
## Turned away: --e2e-expect-reject (it must NOT get a slot) --e2e-expect-reason=match_started (the reason the start gate gives)
## --e2e-expect-status-key=LOCAL_REJECT_MATCH_STARTED (the boot status must show that text) --e2e-reject-wait-s=N (how long it
## waits for the refusal, 15 by default).
## Rejoin: --e2e-rejoin-after-s=N (N seconds after the start it leaves the way the pause menu does, SacrificeFlow.return_to_boot)
## --e2e-away-s=N (and joins again N seconds later). It must sit in the same slot and see its own WizardN; with
## --e2e-expect-reason=grace_over the return must be turned away with that reason instead. No result is awaited then;
## --e2e-linger-s keeps it connected after the return (the seat stays in while another one runs out of grace).
## Network cut: --e2e-cut-watch (the run freezes this process with SIGSTOP after `E2E_READY_TO_CUT`, until the server drops it):
## it waits for the lost server, joins again with the credential it kept and must sit in the same slot and see its own WizardN.
## Every wait is in real seconds (F350: the process may run with `--fixed-fps`, where a SceneTree timer is simulated time).
## Prints `PASS …` / `FAIL …` per check, `E2E_CLOCK <name> at_start=<tick>` (the MatchClock tick when this client saw the gate
## open: about 0 if it waited paused), `E2E_STATUS`, `E2E_LEFT`, `E2E_BACK` and `E2E CLIENT <name> PASS|FAIL`; exit 0 / 1.

const LOCAL_HOST := "127.0.0.1"
const RUNNER_META := "dedicated_client_runner"
const STEP_S := 40.0

var _name := ""
var _fails := 0
var _finished := false
var _slot := 0
var _rejected := ""
var _statuses := PackedStringArray()
var _started_at := -1


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "DedicatedClientRunner"
		# the gate pauses the client tree while the seats load: the runner keeps watching
		twin.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(twin)
		return
	_name = MpBoot.user_value("e2e-name", "?")
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	SacrificeFlow.status_changed.connect(func(text: String) -> void: _statuses.append(text))
	Mp.gate().waiting_changed.connect(_on_waiting_changed)
	_run.call_deferred()


func _on_waiting_changed(waiting: bool, _loaded: int, _expected: int) -> void:
	if waiting or _started_at >= 0:
		return
	_started_at = MatchClock.now()
	print("E2E_CLOCK %s at_start=%d" % [_name, _started_at])


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


func _wait_wall(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _state() -> MatchState:
	return get_tree().get_first_node_in_group(MatchState.GROUP) as MatchState


func _wizard_of(slot: int) -> Node:
	for node in get_tree().get_nodes_in_group(&"wizard"):
		if node.name == "Wizard%d" % slot and int(node.get("owner_slot")) == slot:
			return node
	return null


func _run() -> void:
	_check(SacrificeFlow.join_lan(LOCAL_HOST) == OK, "%s joins the server" % _name)
	if MpBoot.user_flag("e2e-expect-reject"):
		await _expect_turned_away()
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
	if MpBoot.user_flag("e2e-cut-watch"):
		await _rejoin_after_cut()
		await _wait_wall(float(MpBoot.user_value("e2e-linger-s", "0")))
		MpKit.leave()
		_finish()
		return
	if not MpBoot.user_value("e2e-rejoin-after-s", "").is_empty():
		await _rejoin()
		await _wait_wall(float(MpBoot.user_value("e2e-linger-s", "0")))
		MpKit.leave()
		_finish()
		return
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
		await _wait_wall(linger)
	MpKit.leave()
	_finish()


## No slot and no world. With --e2e-expect-reason the refusal must carry that reason; with --e2e-expect-status-key the boot status
## must show that text.
func _expect_turned_away() -> void:
	var reason := MpBoot.user_value("e2e-expect-reason", "")
	var wait_s := float(MpBoot.user_value("e2e-reject-wait-s", "15"))
	if reason.is_empty():
		await _wait_wall(wait_s)
	else:
		await _until(func() -> bool: return not _rejected.is_empty(), wait_s)
		await _wait_wall(0.5)
	_check(_slot == 0 and _state() == null, "%s is left out: no slot, no world (slot %d)" % [_name, _slot])
	if not reason.is_empty():
		_check(_rejected == reason, "%s is turned away with %s (got '%s')" % [_name, reason, _rejected])
	var key := MpBoot.user_value("e2e-expect-status-key", "")
	if not key.is_empty():
		var text := tr(key)
		print("E2E_STATUS %s %s" % [_name, " | ".join(_statuses)])
		var shown := false
		for line in _statuses:
			shown = shown or line.contains(text)
		_check(text != key and shown, "%s: the status shows %s (%s)" % [_name, key, text])


## Leaves N seconds after the start like the pause menu does, and comes back after the away time: the same slot and its own
## wizard, or (with --e2e-expect-reason) turned away.
func _rejoin() -> void:
	await _until(func() -> bool: return _started_at >= 0)
	await _wait_wall(float(MpBoot.user_value("e2e-rejoin-after-s", "0")))
	var first := _slot
	print("E2E_LEFT %s slot=%d" % [_name, first])
	SacrificeFlow.return_to_boot()
	_slot = 0
	_rejected = ""
	await _wait_wall(float(MpBoot.user_value("e2e-away-s", "0")))
	_check(SacrificeFlow.join_lan(LOCAL_HOST) == OK, "%s joins again" % _name)
	if not MpBoot.user_value("e2e-expect-reason", "").is_empty():
		await _expect_turned_away()
		return
	_check(await _until(func() -> bool: return _slot != 0), "%s gets a slot again" % _name)
	_check(_slot == first, "%s is back in slot %d (got %d)" % [_name, first, _slot])
	_check(await _until(func() -> bool: return _state() != null), "%s loaded the match world again" % _name)
	_check(await _until(func() -> bool: return _wizard_of(first) != null), "%s sees its own Wizards/Wizard%d (owner_slot %d)" % [_name, first, first])
	print("E2E_BACK %s slot=%d" % [_name, _slot])


## The run cuts this process off (SIGSTOP) once it says it is ready; the server drops it, then this side loses the server too. It
## joins again with the seat's credential (kept by MpKit for this host:port): the same slot and its own wizard.
func _rejoin_after_cut() -> void:
	await _until(func() -> bool: return _started_at >= 0)
	var first := _slot
	var lost := [false]
	MpKit.server_lost.connect(func() -> void: lost[0] = true)
	print("E2E_READY_TO_CUT %s slot=%d" % [_name, first])
	_check(await _until(func() -> bool: return lost[0], 120.0), "%s lost the server after the cut" % _name)
	print("E2E_LEFT %s slot=%d" % [_name, first])
	_slot = 0
	_rejected = ""
	await _wait_wall(1.0)
	_check(SacrificeFlow.join_lan(LOCAL_HOST) == OK, "%s joins again" % _name)
	_check(await _until(func() -> bool: return _slot != 0), "%s gets a slot again" % _name)
	_check(_slot == first, "%s is back in slot %d (got %d)" % [_name, first, _slot])
	_check(await _until(func() -> bool: return _state() != null), "%s loaded the match world again" % _name)
	_check(await _until(func() -> bool: return _wizard_of(first) != null), "%s sees its own Wizards/Wizard%d (owner_slot %d)" % [_name, first, first])
	print("E2E_BACK %s slot=%d" % [_name, _slot])
