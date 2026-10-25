extends Node3D

## RFC-052 (F360+): the audio lab. Two creatures (unit.tscn: one with a set of the original, one of the user's own), a wizard
## (wizard_body.tscn) and a ListenerFocus on a fixed camera; the bodies are frozen (process off), the lab drives their
## replicated state by hand (swings, shots, mode, Health, Caster.cast_fx_shown, GhostForm.stage) and the bodies' *Sounds
## children turn it into sounds, as on any peer. The criterion is the SoundLog, never the ear.
## - Manual (F6): `debug_audio_event` runs the next step of the script; the label shows the last entry and the bus peaks.
## - Automatic: `--headless … -- --audio-probe --audio-script[=res://debug/audio/lab_<cut>.tres]` runs every step, prints
##   `AUDIO_LAB PASS|FAIL <event> <stream>` per step and `AUDIO_LAB DONE PASS|FAIL (n)`, and quits 0 / 1.
## - `--audio-no-original`: SoundLibrary sees only the script's roots and an empty one (the world, UI, advisor and music sets; the
##   bodies sound as their types say).
## The script (an AudioLabScript .tres) is loaded at run time with load(), so a broken one ends in a FAIL line. Watchdog:
## `timeout_s` of real time.
## 052d: the FX actions call FxBus as a peer does when a broadcast arrives (fx, puff, beam); `spawn` instances a
## projectile or FX scene (frozen) and frees it after the look (a scene FX sounds through its own Sound child; the headless
## FxBus.play_scene draws nothing); `loop` lets go of the loops of the target's SoundEmitter3D nodes and looks again;
## `occupy`/`release` put a Manalith on the Fountain and take it off.
## 052e: the player's voices. `select` leaves the target alone in the lab's Selection (CommandVoice hears Selection.changed),
## `order` emits Orders.requested for it as OrderCommand's request does, `refuse` says a Refusal key on the CommandLog
## (AdvisorVoice), `hit` takes a tenth of a building's Health and `ritual` starts a Desecrate on the local altar or ends it
## completed (AdvisorWatch). An advisor line is looked up as emitter = its code, event `advice`.
## 052f: the music. A CombatGauge (on the wizard, short hold), a MusicDirector (music/james) and a MatchState (no
## DefeatRule: the death steps must not end the match). `battle` pins the gauge, `ritual convert`/`desecrate`/`complete`
## start and end a ritual next to the camera, `result won` ends the match, `god` changes the set; the wizard's `damaged`
## keeps the battle on. A music entry is emitter `music`, event = the mood (MusicMood).
## 052g: the ambience (AmbienceDirector, ambience/james): `bed`, `ambient`, `god`, and `wait` with `from_wait` (a one-shot
## of the set's interval). An ambience entry is emitter `ambience`, event `bed` or `ambient`.
## 052h: the UI and the sacrifice. `press` emits a button's `pressed` (SoundBus clicks it: event `click`), `menu` opens
## (`arg` open) or cancels (cancel) the radial menu (MenuSounds: `menu_open`, `menu_back`), `ritual_phase` sets the lab
## Ritual's replicated phase (`arg` shoot, wait...) and `ritual_end` its outcome (`arg` completed, aborted), as a client
## receives them (RitualSounds); `collect` puts the lab Soul in COLLECTING (SoulSounds).
## 052i: your own sounds. lab_052i.tres plays the testmonster set that tools/bake/new_creature.gd writes from two fixture
## files (debug/audio/fixtures/custom_sounds/creatures/testmonster/) under user://, or the committed copy in
## debug/audio/fixtures/custom_baked/; `stream_has` checks the file that sounded.
## 055o-b: a script may give its "Custom" creature and its "Wizard" other `sounds` (custom_set, wizard_set): the bodies sound as
## their CreatureType and WizardType say, so a fixture replaces the type's set for the run.

const SCRIPT_FLAG := "audio-script"
const NO_ORIGINAL_FLAG := "audio-no-original"
const EMPTY_ROOT := "res://debug/audio/fixtures/empty/"
## AudioLabStep.Expect (read without naming the class: the step script is loaded at run time).
const PLAYED := 0
const SILENT := 1
const IF_SET := 2
## 052h: the `menu` action's argument -> the RadialMenu signal it ends in.
const MENU_SIGNALS := {"open": &"opened", "cancel": &"cancelled"}

@export_file("*.tres") var script_path := "res://debug/audio/lab_052c.tres"
@export var label: Label
@export_group("Voices (052e)")
@export var selection: Node
@export var orders: Node
@export var command_log: CommandLog
@export var command_voice: CommandVoice
@export var advisor: AdvisorVoice
@export var advisor_watch: AdvisorWatch
@export_group("Music and ambience (052f, 052g)")
@export var music: MusicDirector
@export var ambience: AmbienceDirector
@export var gauge: CombatGauge
@export var match_state: MatchState
@export_group("")
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
## The WizardType whose `sounds` the lab replaced, and what it had (put back at the end: the catalog type is shared).
var _wizard_type: WizardType
var _wizard_sounds: SoundSet


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
	roots.append_array(PackedStringArray(_lab.get("fallback_roots")) if _lab.get("fallback_roots") != null else PackedStringArray())
	SoundLibrary.roots = roots
	SoundLibrary.clear_cache()
	## The directors looked their sets up on entering the tree, with the default roots (052f, 052g).
	if music != null:
		music.use_set(music.set_path)
	if ambience != null:
		ambience.use_set(ambience.set_path)
	_assign_body_sets()
	SoundBus.reseed(5200)
	SoundBus.sound_log.clear()
	print("AUDIO_LAB %s: %d pasos, raíces %s" % [_lab.get("cut"), _lab.get("steps").size(), roots])
	_show("listo: %s pasos (%s)" % [_lab.get("steps").size(), InputMap.action_get_events("debug_audio_event").map(func(e: InputEvent) -> String: return e.as_text())])
	if _auto:
		while _next < _lab.get("steps").size() and not _done:
			await _run_step()
		_end()


## The fixture sounds of the script's "Custom" creature and "Wizard": what their type says is replaced for this run.
func _assign_body_sets() -> void:
	var custom := get_node_or_null("Custom") as UnitBody
	var custom_set := _custom_set()
	if custom != null and custom.type != null and custom_set != null:
		custom.type = custom.type.duplicate() as CreatureType
		custom.type.sounds = custom_set
	var wizard := get_node_or_null("Wizard") as WizardBody
	var wizard_set := _lab.get("wizard_set") as SoundSet
	if wizard != null and wizard.clip_type() != null and wizard_set != null:
		_wizard_type = wizard.clip_type()
		_wizard_sounds = _wizard_type.sounds
		_wizard_type.sounds = wizard_set


func _custom_set() -> SoundSet:
	for path in PackedStringArray(_lab.get("custom_set_paths")):
		if ResourceLoader.exists(path):
			return load(path) as SoundSet
	return _lab.get("custom_set") as SoundSet


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
	var before: int = SoundBus.sound_log.entries().size()
	if wait_s > 0.0:
		var until := BodySounds.game_seconds() + wait_s
		while BodySounds.game_seconds() < until:
			await get_tree().physics_frame
	var body := get_node_or_null(step.get("target") as NodePath)
	var event := StringName(step.get("event"))
	var action := StringName(step.get("action"))
	var arg := str(step.get("arg"))
	var expected_cue: Variant = _expected_cue(body, action, arg, event, StringName(step.get("emitter")))
	if body == null or (expected_cue is bool and not expected_cue):
		_report(false, event, "sin nodo %s" % step.get("target"))
		_busy = false
		return
	var expect := int(step.get("expect"))
	if expect == IF_SET:
		expect = PLAYED if expected_cue is SoundCue or expected_cue is AudioStream else SILENT
	var emitter := StringName(step.get("emitter"))
	if emitter.is_empty():
		emitter = StringName(body.name)
	if not bool(step.get("from_wait")):
		before = SoundBus.sound_log.entries().size()
	var acted := _act(body, action, arg)
	if music != null and action in [&"ritual", &"result", &"damaged"]:
		music.look()
	for _i in settle_frames:
		await get_tree().process_frame
	_free_spawned()
	var found := _played_since(before, emitter, event)
	if not acted:
		_report(false, event, "acción desconocida %s" % step.get("action"))
	elif expect == PLAYED:
		var stream_has := str(step.get("stream_has")) if step.get("stream_has") != null else ""
		var stream := str(found.get("stream", "-"))
		if not found.is_empty() and not stream_has.is_empty() and not stream.contains(stream_has):
			_report(false, event, "sonó %s y no %s" % [stream, stream_has])
		else:
			_report(not found.is_empty(), event, stream if not found.is_empty() else "no sonó (%s)" % body.name)
	else:
		_report(found.is_empty(), event, "-" if found.is_empty() else "sonó y no debía: %s" % found.get("stream"))
	_busy = false


## The cue the step's emitter has for `event` now (a SoundCue), null when it has none, false when the target cannot do it.
func _expected_cue(body: Node, action: StringName, arg: String, event: StringName, emitter: StringName = &"") -> Variant:
	if body == null:
		return false
	if emitter == MusicDirector.EMITTER:
		return _music_expected(action, arg, event)
	if emitter == AmbienceDirector.EMITTER:
		return _ambience_expected(action, arg, event)
	if event == SoundEvent.ADVICE:
		if advisor == null:
			return false
		return advisor.cue_for(advisor.code_for_refusal(StringName(arg)) if action == &"refuse" else emitter)
	match action:
		&"press":
			return SoundBus.ui_cue_for(body as BaseButton) if body is BaseButton else false
		&"menu":
			var menu_sounds := body.get_node_or_null("MenuSounds") as MenuSounds
			return menu_sounds.cue_for(MENU_SIGNALS.get(arg, &"")) if menu_sounds != null else false
		&"select", &"order":
			return command_voice.cue_for(body as UnitBody, event) if command_voice != null else false
		&"fx":
			return SoundBus.fx_sounds.cue_of(FxBus.KIND_BURST, arg)
		&"puff":
			return SoundBus.fx_sounds.cue_of(FxBus.KIND_PUFF, arg)
		&"beam":
			return SoundBus.fx_sounds.cue_of(FxBus.KIND_BEAM, arg)
		&"spawn":
			return true
		&"loop", &"occupy", &"release":
			var emitters := _emitters_of(body)
			return emitters[0].cue if not emitters.is_empty() else false
	var sounds := _sounds_of(body)
	return sounds.cue_for(event) if sounds != null else false


## 052f: a track of the mood `event` in the set the director has (or will have after `god`), null when it has none.
func _music_expected(action: StringName, arg: String, event: StringName) -> Variant:
	if music == null:
		return false
	var music_set := music.music_set
	if action == &"god":
		music_set = music.resolve("music/%s" % arg)
	if music_set == null:
		return null
	var tracks := music_set.tracks(event)
	return tracks[0] if not tracks.is_empty() else null


## 052g: the bed cue (bed, god) or a one-shot cue (ambient, wait) the director has, null when it has none.
func _ambience_expected(action: StringName, arg: String, event: StringName) -> Variant:
	if ambience == null:
		return false
	if event == SoundEvent.BED:
		var ambience_set := ambience.ambience_set
		if action == &"god":
			ambience_set = SoundLibrary.find("ambience/%s" % arg) as AmbienceSet
		var bed := ambience_set.bed if ambience_set != null else null
		return bed if bed != null and not bed.is_silent() else null
	var cues := AmbienceDirector.one_shot_cues(ambience.ambience_set)
	return cues[0] if not cues.is_empty() else null


## Drives the replicated state the *Sounds child listens to, as a client would receive it; the FX actions call FxBus as
## a peer does when a broadcast arrives.
func _act(body: Node, action: StringName, arg := "") -> bool:
	## Where an FX or a projectile goes: the target's position (a director has none).
	var spot := (body as Node3D).global_position if body is Node3D else Vector3.ZERO
	match action:
		&"music":
			if body != music:
				return false
			if arg == "restart":
				music.restart()
			else:
				music.look()
			return true
		&"battle":
			if gauge == null:
				return false
			gauge.force(float(arg) if arg.is_valid_float() else 1.0)
			return true
		&"result":
			return _result(arg)
		&"god":
			if body == music:
				music.use_god(StringName(arg))
				return true
			if body == ambience:
				ambience.use_god(StringName(arg))
				return true
			return false
		&"bed":
			if body != ambience:
				return false
			ambience.restart_bed()
			return true
		&"ambient":
			if body != ambience:
				return false
			ambience.play_one_shot()
			return true
		&"wait":
			return true
		&"fx":
			FxBus.play(arg, spot + Vector3.UP)
			return true
		&"puff":
			FxBus.play_puff(arg, spot + Vector3.UP)
			return true
		&"beam":
			FxBus.play_beam(arg, spot + Vector3.UP * 4.0, spot)
			return true
		&"scene":
			FxBus.play_scene(arg, spot, {})
			return true
		&"spawn":
			return body is Node3D and _spawn(body as Node3D, arg)
		&"loop":
			for emitter in _emitters_of(body):
				_relisten(emitter)
			return true
		&"select":
			if selection == null:
				return false
			selection.call("select_only", [body])
			return true
		&"order":
			if orders == null:
				return false
			orders.emit_signal("requested", [body], arg)
			return true
		&"refuse":
			if command_log == null:
				return false
			command_log.say(arg)
			return true
		&"hit":
			var health := body.get_node_or_null("Health") as Health
			if health == null or advisor_watch == null:
				return false
			advisor_watch.scan()
			_hit(health)
			return true
		&"ritual":
			return _ritual(arg)
		&"press":
			if not body is BaseButton:
				return false
			(body as BaseButton).pressed.emit()
			return true
		&"menu":
			var radial := body as RadialMenu
			if radial == null or not MENU_SIGNALS.has(arg):
				return false
			if arg == "open":
				radial.open_at(Vector2(400.0, 300.0))
			else:
				radial.cancel()
			return true
		&"ritual_phase":
			var ritual := body as Ritual
			if ritual == null or not Ritual.Phase.has(arg.to_upper()):
				return false
			ritual.phase = Ritual.Phase[arg.to_upper()]
			return true
		&"ritual_end":
			var ended := body as Ritual
			if ended == null or not Ritual.Outcome.has(arg.to_upper()):
				return false
			ended.outcome = Ritual.Outcome[arg.to_upper()]
			return true
		&"collect":
			var soul := body as Soul
			if soul == null:
				return false
			soul.state = Soul.State.COLLECTING
			return true
		&"occupy", &"release":
			if not body.has_method("occupy"):
				return false
			for emitter in _emitters_of(body):
				_relisten(emitter)
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


## A tenth of the bar off, never to 0 (whatever the bar: a building's may be 1).
func _hit(health: Health) -> void:
	if health.maximum <= 0.0:
		health.maximum = 100.0
		health.current = 100.0
	health.current = maxf(health.current - health.maximum * 0.1, health.maximum * 0.05)


## 052e: `desecrate` adds a Desecrate ritual (frozen) on the local side's altar, cast by the local side; `complete` ends it
## completed. AdvisorWatch looks at once (it would on its next scan).
func _ritual(arg: String) -> bool:
	if advisor_watch == null:
		return false
	match arg:
		"desecrate", "convert":
			var ritual := Ritual.new()
			ritual.name = "LabRitual"
			ritual.process_mode = Node.PROCESS_MODE_DISABLED
			if arg == "desecrate":
				ritual.kind = Ritual.Kind.DESECRATE
				ritual.target_slot = MpKit.local_slot()
			else:
				ritual.kind = Ritual.Kind.CONVERT
				ritual.target_slot = MpKit.local_slot() + 1
			ritual.caster_slot = MpKit.local_slot()
			add_child(ritual)
			ritual.phase = Ritual.Phase.SETUP
		"complete":
			var ritual := get_node_or_null("LabRitual") as Ritual
			if ritual == null:
				return false
			ritual.outcome = Ritual.Outcome.COMPLETED
			advisor_watch.scan()
			## Its name is free for the next ritual of the script (052f starts more than one).
			ritual.name = "LabRitualDone"
			return true
		_:
			return false
	advisor_watch.scan()
	return true


## 052f: `won` ends the lab's MatchState with the local side as the winner (once: a match has one result).
func _result(arg: String) -> bool:
	if match_state == null or arg != "won":
		return false
	match_state.end_match(MpKit.local_slot())
	return true


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


## Out of the tree at once (queue_free alone waits for the frame's end): the next step's "LabProjectile" keeps its name.
func _free_spawned() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			if node.get_parent() == self:
				remove_child(node)
			node.queue_free()
	_spawned.clear()


## A loop lets go and looks again, as if the listener had just come into range.
func _relisten(emitter: SoundEmitter3D) -> void:
	SoundBus.release_loop(emitter)
	emitter.set_active(emitter.active)


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
	var entries: Array[Dictionary] = SoundBus.sound_log.entries()
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
	if _wizard_type != null:
		_wizard_type.sounds = _wizard_sounds
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
