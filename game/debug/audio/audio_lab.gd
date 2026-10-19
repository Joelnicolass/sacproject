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
## 052d: the FX actions call FxBus as a peer does when a broadcast arrives (fx, puff, beam, scene); `spawn` instances a
## projectile scene (frozen) and frees it after the look; `loop` restarts the loops of the target's SoundEmitter3D nodes;
## `occupy`/`release` put a Manalith on the Fountain and take it off.

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
var _spawned: Array[Node] = []


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
	## The emitters resolved their cues on entering the tree, with the default roots.
	for node in find_children("*", "SoundEmitter3D", true, false):
		(node as SoundEmitter3D).restart()
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
	var action := StringName(step.get("action"))
	var arg := str(step.get("arg"))
	var expected_cue: Variant = _expected_cue(body, action, arg, event)
	if body == null or (expected_cue is bool and not expected_cue):
		_report(false, event, "sin nodo %s" % step.get("target"))
		_busy = false
		return
	var expect := int(step.get("expect"))
	if expect == IF_SET:
		expect = PLAYED if expected_cue is SoundCue else SILENT
	var emitter := StringName(step.get("emitter"))
	if emitter.is_empty():
		emitter = StringName(body.name)
	var before := SoundBus.sound_log.entries().size()
	var acted := _act(body, action, arg)
	for _i in settle_frames:
		await get_tree().process_frame
	_free_spawned()
	var found := _played_since(before, emitter, event)
	if not acted:
		_report(false, event, "acción desconocida %s" % step.get("action"))
	elif expect == PLAYED:
		_report(not found.is_empty(), event, str(found.get("stream", "-")) if not found.is_empty() else "no sonó (%s)" % body.name)
	else:
		_report(found.is_empty(), event, "-" if found.is_empty() else "sonó y no debía: %s" % found.get("stream"))
	_busy = false


## The cue the step's emitter has for `event` now (a SoundCue), null when it has none, false when the target cannot do it.
func _expected_cue(body: Node3D, action: StringName, arg: String, event: StringName) -> Variant:
	if body == null:
		return false
	match action:
		&"fx":
			return SoundBus.fx_cue(FxBus.KIND_BURST, arg)
		&"puff":
			return SoundBus.fx_cue(FxBus.KIND_PUFF, arg)
		&"beam":
			return SoundBus.fx_cue(FxBus.KIND_BEAM, arg)
		&"scene":
			return SoundBus.fx_cue(FxBus.KIND_SCENE, arg)
		&"spawn":
			return true
		&"loop", &"occupy", &"release":
			var emitters := _emitters_of(body)
			return emitters[0].resolved_cue() if not emitters.is_empty() else false
	var sounds := _sounds_of(body)
	return sounds.cue_for(event) if sounds != null else false


## Drives the replicated state the *Sounds child listens to, as a client would receive it; the FX actions call FxBus as
## a peer does when a broadcast arrives.
func _act(body: Node3D, action: StringName, arg := "") -> bool:
	match action:
		&"fx":
			FxBus.play(arg, body.global_position + Vector3.UP)
			return true
		&"puff":
			FxBus.play_puff(arg, body.global_position + Vector3.UP)
			return true
		&"beam":
			FxBus.play_beam(arg, body.global_position + Vector3.UP * 4.0, body.global_position)
			return true
		&"scene":
			FxBus.play_scene(arg, body.global_position, {})
			return true
		&"spawn":
			return _spawn(body, arg)
		&"loop":
			for emitter in _emitters_of(body):
				emitter.restart()
			return true
		&"occupy", &"release":
			if not body.has_method("occupy"):
				return false
			for emitter in _emitters_of(body):
				emitter.restart()
			if action == &"occupy":
				body.call("occupy", get_node("Wizard").get_path())
			else:
				body.call("release")
			return true
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


## A projectile scene of `path`, frozen, at the target (its SoundEmitter3D plays on entering the tree). Freed after the look.
func _spawn(body: Node3D, path: String) -> bool:
	var packed := load(path) as PackedScene if ResourceLoader.exists(path) else null
	var node := packed.instantiate() as Node3D if packed != null else null
	if node == null:
		return false
	var at := body.global_position + Vector3.UP
	if node.has_method("setup"):
		node.call("setup", {"name": "LabProjectile", "x": at.x, "y": at.y, "z": at.z, "tx": at.x, "ty": at.y, "tz": at.z + 10.0,
			"speed": 0.0, "acceleration": 0.0})
	node.name = "LabProjectile"
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.position = at
	add_child(node)
	_spawned.append(node)
	return true


func _free_spawned() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()


## The SoundEmitter3D loops under `body` (any depth).
func _emitters_of(body: Node) -> Array[SoundEmitter3D]:
	var out: Array[SoundEmitter3D] = []
	for node in body.find_children("*", "SoundEmitter3D", true, false):
		var emitter := node as SoundEmitter3D
		if emitter.loop:
			out.append(emitter)
	return out


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
	SoundBus.shutdown()
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
