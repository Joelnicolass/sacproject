extends Node

## The one place that plays SoundCues: it owns the players (32 in the world, 8 for the UI and the voices) and hands every
## request to its VoiceMixer, which decides what plays and what is dropped. It decides how, never when: the Sounds/Voice/
## Director nodes ask. Every request, played or dropped, goes to `sound_log`, which is what the cases and the lab check.
## With the AudioGate closed (dedicated, headless without --audio-probe) it builds nothing and every play is false.
## Ref: RFC-052 052a-052h (F360-F367).

@export_range(1, 128) var pool_3d_size := 32
@export_range(1, 64) var pool_2d_size := 8
@export var rng_seed := 5200
@export_range(1, 1024) var log_capacity := 64
## Loops playing at once (fountains, manaliths, altars); they also count in `pool_3d_size`.
@export_range(0, 64) var max_loops_3d := 8:
	set(value):
		max_loops_3d = value
		_mixer.max_loops = value
@export var fx_sounds: FxSounds
@export var ui_clicks: UiClickSounds

var sound_log: SoundLog  # null while the gate is closed
var prefs: AudioPrefs
## Where the player hears from (ListenerFocus); null = the viewport's camera.
var listener: Node3D

var _mixer := VoiceMixer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not AudioGate.is_open():
		set_process(false)
		return
	_mixer.live = true
	_mixer.playback.reseed(rng_seed)
	sound_log = SoundLog.new(log_capacity)
	_mixer.sound_log = sound_log
	for i in pool_3d_size:
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice3D_%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_mixer.pool_3d.add(player)
	for i in pool_2d_size:
		var player := AudioStreamPlayer.new()
		player.name = "Voice2D_%d" % i
		add_child(player)
		_mixer.pool_2d.add(player)
	prefs = load(AudioPrefs.SHARED_PATH) as AudioPrefs
	if prefs == null:
		push_warning("SoundBus: falta %s; los buses quedan como están." % AudioPrefs.SHARED_PATH)
		return
	prefs.changed.connect(apply_prefs)
	apply_prefs()


func _process(delta: float) -> void:
	_mixer.playback.clock += delta


func is_active() -> bool:
	return _mixer.live


func can_play() -> bool:
	return _mixer.can_play()


## Where the player hears from: `listener`, else the viewport's camera; INF when there is neither.
func listener_position() -> Vector3:
	if is_instance_valid(listener) and listener.is_inside_tree():
		return listener.global_position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera.global_position if camera != null else Vector3.INF


## A cue in the world at `at`. False when it was dropped (gate closed, silent, cooldown, limits).
func play_3d(cue: SoundCue, at: Vector3, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _mixer.request(cue, true, at, emitter, event)


## A cue with no position (UI, voices, music stingers).
func play_2d(cue: SoundCue, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _mixer.request(cue, false, Vector3.ZERO, emitter, event)


## A cue on a player the caller owns (CommandVoice, AdvisorVoice): it says one line at a time and decides what cuts what.
func play_on(player: AudioStreamPlayer, cue: SoundCue, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _mixer.play_on(player, cue, emitter, event)


## A stream a player of the caller's started on its own (MusicDirector): a played entry only.
func log_played(emitter: StringName, event: StringName, stream: AudioStream) -> void:
	if _mixer.live:
		sound_log.add(emitter, event, stream, true)


## A request a voice channel turned down before it reached a player (queue full, a repeated line): a log entry only.
func log_dropped(emitter: StringName, event: StringName, reason: StringName) -> void:
	if _mixer.live:
		_mixer.drop(emitter, event, reason)


func adopt_channel(player: AudioStreamPlayer) -> void:
	_mixer.adopt_channel(player)


## Plays `cue` in a loop on a SoundEmitter3D's own player while it holds the claim; false (and a log entry) when refused.
func claim_loop(player: AudioStreamPlayer3D, cue: SoundCue, emitter: StringName = &"", event: StringName = SoundEvent.LOOP) -> bool:
	return _mixer.claim_loop(player, cue, emitter, event)


func release_loop(player: AudioStreamPlayer3D) -> void:
	_mixer.loops.release(player)


func holds_loop(player: AudioStreamPlayer3D) -> bool:
	return _mixer.loops.holds(player)


## Voices playing now (3D: the pool and the loops; 2D: the pool), of `cue` or of any cue when null.
func active_voices(in_3d: bool, cue: SoundCue = null) -> int:
	return _mixer.active_voices(in_3d, cue)


func active_loops() -> int:
	return _mixer.loops.active()


func pool_size(in_3d: bool) -> int:
	return (_mixer.pool_3d if in_3d else _mixer.pool_2d).size()


func stop_all() -> void:
	_mixer.stop_all()


## stop_all() and nothing plays or claims after it: a run about to quit (a loop claimed then would leak at exit).
func shutdown() -> void:
	_mixer.stop_all()
	_mixer.closed = true


func apply_prefs() -> void:
	BusLevels.apply(prefs)


## Seeds the generator of the variants and the pitch (the cases and the lab).
func reseed(value: int) -> void:
	_mixer.playback.reseed(value)
