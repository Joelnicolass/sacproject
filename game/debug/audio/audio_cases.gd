extends Node

## RFC-052 052a (F360): runner of the audio cases. `--expect-gate=open|closed` says what this process must see:
## - open (`--audio-probe --user-settings=user://t_audio.cfg`): gate, prefs, SoundBus, original-set and body-set cases;
## - closed (plain headless, `--dedicated`, `--room-server`): gate cases and the closed SoundEmitter3D (nothing built,
##   nothing loaded).
## Both modes also run the FX sound cases (052d), the voice cases (052e) and the music and ambience cases (052f, 052g) and
## the UI and sacrifice cases (052h) for their gate.
## Prints `<case>: PASS|FAIL` and `AUDIO CASES PASS|FAIL (n)`; headless quits with 0 / 1.
## Watchdog: past `timeout_s` it prints `AUDIO CASES FAIL timeout` and quits 1. The case scripts are loaded at run time
## (not preloaded), so one that fails to compile still ends in a FAIL line instead of a runner without a script.
## agent/runs/run_audio_cases.sh runs every mode.

const GATE_CASES := "res://debug/audio/audio_gate_cases.gd"
const PREFS_CASES := "res://debug/audio/audio_prefs_cases.gd"
const BUS_CASES := "res://debug/audio/sound_bus_cases.gd"
const ORIGINAL_CASES := "res://debug/audio/original_sets_cases.gd"
const BODY_CASES := "res://debug/audio/body_sounds_cases.gd"
const FX_CASES := "res://debug/audio/fx_sounds_cases.gd"
const VOICE_CASES := "res://debug/audio/voice_cases.gd"
const MUSIC_CASES := "res://debug/audio/music_mood_cases.gd"
const UI_SACRIFICE_CASES := "res://debug/audio/ui_sacrifice_cases.gd"

## Real seconds (not game time: --fixed-fps would stretch a game-time timer).
@export var timeout_s := 20.0

var _done := false


func _ready() -> void:
	_watchdog()
	_run.call_deferred()


func _watchdog() -> void:
	var limit := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _done:
		await get_tree().process_frame
		if Time.get_ticks_msec() > limit and not _done:
			_done = true
			print("AUDIO CASES FAIL timeout")
			get_tree().quit(1)


func _run() -> void:
	var expect := MpBoot.user_value("expect-gate", "")
	var results := {}
	if expect not in ["open", "closed"]:
		results["expect_gate_arg"] = {"ok": false, "reason": "falta --expect-gate=open|closed"}
	else:
		var gate := _cases(GATE_CASES)
		if gate == null:
			results["audio_gate_cases"] = {"ok": false, "reason": "no compila"}
		else:
			results.merge(await gate.run(self, expect == "open"))
		var fx := _cases(FX_CASES)
		if fx == null:
			results["fx_sounds_cases"] = {"ok": false, "reason": "no compila"}
		elif expect == "closed":
			results.merge(await fx.run(self, false))
		var voices := _cases(VOICE_CASES)
		if voices == null:
			results["voice_cases"] = {"ok": false, "reason": "no compila"}
		elif expect == "closed":
			results.merge(await voices.run(self, false))
		var music := _cases(MUSIC_CASES)
		if music == null:
			results["music_mood_cases"] = {"ok": false, "reason": "no compila"}
		elif expect == "closed":
			results.merge(await music.run(self, false))
		var ui_sacrifice := _cases(UI_SACRIFICE_CASES)
		if ui_sacrifice == null:
			results["ui_sacrifice_cases"] = {"ok": false, "reason": "no compila"}
		elif expect == "closed":
			results.merge(await ui_sacrifice.run(self, false))
		if expect == "open":
			var prefs := _cases(PREFS_CASES)
			var bus := _cases(BUS_CASES)
			if prefs == null or bus == null:
				results["audio_cases_compile"] = {"ok": false, "reason": "un script de casos no compila"}
			else:
				results.merge(prefs.run(self))
				results.merge(await bus.run(self))
			var original := _cases(ORIGINAL_CASES)
			if original == null:
				results["original_sets_cases"] = {"ok": false, "reason": "no compila"}
			else:
				results.merge(original.run(self))
			var body := _cases(BODY_CASES)
			if body == null:
				results["body_sounds_cases"] = {"ok": false, "reason": "no compila"}
			else:
				results.merge(body.run(self))
			if fx != null:
				results.merge(await fx.run(self, true))
			if voices != null:
				results.merge(await voices.run(self, true))
			if music != null:
				results.merge(await music.run(self, true))
			if ui_sacrifice != null:
				results.merge(await ui_sacrifice.run(self, true))
	if _done:
		return
	_done = true
	var failures := 0
	print("== Audio cases (gate %s) ==" % expect)
	for name in results:
		var item: Dictionary = results[name]
		var ok := bool(item.get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % item)
	print("AUDIO CASES PASS" if failures == 0 else "AUDIO CASES FAIL (%d)" % failures)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures == 0 else 1)


static func _cases(path: String) -> Object:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	return script.new()
