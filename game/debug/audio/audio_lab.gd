extends Node3D

## RFC-052 (F360+): the audio lab. Two creatures (unit.tscn: one with a set of the original, one of the user's own), a wizard
## (wizard_body.tscn) and a ListenerFocus on a fixed camera; the bodies are frozen (process off), the lab drives their
## replicated state by hand (swings, shots, mode, Health, Caster.cast_fx_shown, GhostForm.stage) and the bodies' *Sounds
## children turn it into sounds, as on any peer. The criterion is the SoundLog, never the ear.
## - Manual (F6): `debug_audio_event` runs the next step of the script; the label shows the last entry and the bus peaks.
## - Automatic: `--headless … -- --audio-probe --audio-script[=res://debug/audio/lab_<cut>.tres]` runs every step, prints
##   `AUDIO_LAB PASS|FAIL <event> <stream>` per step and `AUDIO_LAB DONE PASS|FAIL (n)`, and quits 0 / 1.
## - `--audio-no-original`: SoundLibrary sees only the script's roots and an empty one (a clone without the original's audio).
## The script (an AudioLabScript .tres) is loaded at run time with load(), so a broken one ends in a FAIL line. Watchdog:
## `timeout_s` of real time.

const SCRIPT_FLAG := "audio-script"
const NO_ORIGINAL_FLAG := "audio-no-original"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"
## AudioLabStep.Expect (read without naming the class: the step script is loaded at run time).
const PLAYED := 0
const SILENT := 1
const IF_SET := 2

@export_file("*.tres") var script_path := "res://debug/audio/lab_052c.tres"
@export var label: Label
## Real seconds (game time would stretch under --fixed-fps).
@export var timeout_s := 20.0
## Process frames between an action and the look at the log.
@export var settle_frames := 2

var _lab: Resource
var _next := 0
var _failures := 0
var _done := false
var _auto := false
var _busy := false
var _status := ""


func _ready() -> void:
	_auto = MpBoot.user_flag(SCRIPT_FLAG) or not MpBoot.user_value(SCRIPT_FLAG, "").is_empty()
	if _auto:
		_watchdog()
	_start.call_deferred()


func _start() -> void:
	var path := MpBoot.user_value(SCRIPT_FLAG, "")
	if path.is_empty():
		path = script_path
	_lab = load(path) if ResourceLoader.exists(path) else null
	if _lab == null or not (_lab.get("steps") is Array):
		_report(false, &"script", path + " no carga")
		_end()
		return
	if not SoundBus.is_active():
		_report(false, &"gate", "cerrado: corré con --audio-probe")
		_end()
		return
	var roots := PackedStringArray(_lab.get("roots"))
	if MpBoot.user_flag(NO_ORIGINAL_FLAG):
		roots.append(EMPTY_ROOT)
	else:
		roots.append_array(SoundLibrary.DEFAULT_ROOTS)
	SoundLibrary.roots = roots
	SoundLibrary.clear_cache()
	SoundBus.reseed(5200)
	SoundBus.sound_log.clear()
	print("AUDIO_LAB %s: %d pasos, raíces %s" % [_lab.get("cut"), _lab.get("steps").size(), roots])
	_show("listo: %s pasos (%s)" % [_lab.get("steps").size(), InputMap.action_get_events("debug_audio_event").map(func(e: InputEvent) -> String: return e.as_text())])
	if _auto:
		while _next < _lab.get("steps").size() and not _done:
			await _run_step()
		_end()


func _unhandled_input(event: InputEvent) -> void:
	if _auto or _lab == null or _busy or not event.is_action_pressed("debug_audio_event"):
		return
	if _next >= _lab.get("steps").size():
		_next = 0
		SoundBus.sound_log.clear()
	_run_step()


func _process(_delta: float) -> void:
	if label == null or _auto:
		return
	var peaks := PackedStringArray()
	for bus in AudioPrefs.BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			peaks.append("%s %.0f" % [bus, AudioServer.get_bus_peak_volume_left_db(index, 0)])
	var last: Dictionary = SoundBus.sound_log.last() if SoundBus.sound_log != null else {}
	label.text = "%s\n%s\npicos dB: %s" % [_status, _entry_text(last), "  ".join(peaks)]



func _run_step() -> void:
	_busy = true
	var step: Resource = _lab.get("steps")[_next]
	_next += 1
	var wait_s := float(step.get("wait_s"))
	if wait_s > 0.0:
		var until := BodySounds.game_seconds() + wait_s
		while BodySounds.game_seconds() < until:
			await get_tree().physics_frame
	var body := get_node_or_null(step.get("target") as NodePath) as Node3D
	var event := StringName(step.get("event"))
	var sounds := _sounds_of(body)
	if body == null or sounds == null:
		_report(false, event, "sin nodo %s" % step.get("target"))
		_busy = false
		return
	var expect := int(step.get("expect"))
	if expect == IF_SET:
		expect = PLAYED if sounds.cue_for(event) != null else SILENT
	var before := SoundBus.sound_log.entries().size()
	var acted := _act(body, StringName(step.get("action")))
	for _i in settle_frames:
		await get_tree().process_frame
	var found := _played_since(before, StringName(body.name), event)
	if not acted:
		_report(false, event, "acción desconocida %s" % step.get("action"))
	elif expect == PLAYED:
		_report(not found.is_empty(), event, str(found.get("stream", "-")) if not found.is_empty() else "no sonó (%s)" % body.name)
	else:
		_report(found.is_empty(), event, "-" if found.is_empty() else "sonó y no debía: %s" % found.get("stream"))
	_busy = false


## Drives the replicated state the *Sounds child listens to, as a client would receive it.
func _act(body: Node3D, action: StringName) -> bool:
	if body is UnitBody:
		var unit := body as UnitBody
		match action:
			&"summon":
				unit.mode = UnitBody.Mode.SUMMONING
				unit.mode = UnitBody.Mode.IDLE
			&"swing":
				unit.swings += 1
			&"shoot":
				unit.shots += 1
			&"damaged":
				_hurt(unit.get_node("Health"))
			&"death":
				unit.mode = UnitBody.Mode.DEAD
			_:
				return false
		return true
	if body is WizardBody:
		var wizard := body as WizardBody
		var caster := wizard.get_node("Caster") as Caster
		var ghost := wizard.get_node("GhostForm") as GhostForm
		match action:
			&"cast":
				caster.cast_fx_shown = ""
				caster.cast_fx_shown = "cast_lab"
				caster.cast_fx_shown = ""
			&"damaged":
				_hurt(wizard.get_node("Health"))
			&"death":
				ghost.stage = GhostForm.Stage.DYING
			&"ghost":
				ghost.stage = GhostForm.Stage.RISING
			_:
				return false
		return true
	return false


## A tenth of the bar off (never to 0: a death is its own step).
func _hurt(health: Health) -> void:
	var full := maxf(health.maximum, 100.0)
	if health.maximum <= 0.0:
		health.maximum = full
		health.current = full
	health.current = maxf(health.current - full * 0.1, full * 0.05)


func _sounds_of(body: Node) -> BodySounds:
	if body == null:
		return null
	for child in body.get_children():
		if child is BodySounds:
			return child
	return null


func _played_since(before: int, emitter: StringName, event: StringName) -> Dictionary:
	var entries := SoundBus.sound_log.entries()
	for i in range(mini(before, entries.size()), entries.size()):
		var entry: Dictionary = entries[i]
		if entry.emitter == emitter and entry.event == event and bool(entry.played):
			return entry
	return {}


func _report(ok: bool, event: StringName, detail: String) -> void:
	if not ok:
		_failures += 1
	var line := "AUDIO_LAB %s %s %s" % ["PASS" if ok else "FAIL", event, detail]
	print(line)
	_show(line)


func _show(text: String) -> void:
	_status = text


func _entry_text(entry: Dictionary) -> String:
	if entry.is_empty():
		return "(log vacío)"
	return "%s %s %s" % [entry.emitter, entry.event, entry.stream if entry.played else "descartado: %s" % entry.reason]


func _end() -> void:
	if _done:
		return
	_done = true
	if not _auto:
		return
	print("AUDIO_LAB DONE %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	## The audio server lets go of the playbacks a moment (real time) after a stop; quitting before leaks them at exit.
	SoundBus.stop_all()
	SoundLibrary.reset_roots()
	var release_at := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < release_at:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _watchdog() -> void:
	var limit := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _done:
		await get_tree().process_frame
		if Time.get_ticks_msec() > limit and not _done:
			_done = true
			print("AUDIO_LAB DONE FAIL timeout")
			get_tree().quit(1)
