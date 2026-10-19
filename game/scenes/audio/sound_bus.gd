extends Node

## Autoload SoundBus (RFC-052 052a, F360): plays SoundCues. It decides *how* a sound plays, never *when* (that is the
## Sounds/Voice/Director nodes of later cuts).
## - Two pools built once: `pool_3d_size` AudioStreamPlayer3D (world) and `pool_2d_size` AudioStreamPlayer (UI, voices).
## - Per cue: `cooldown_s` (a play too soon after the previous one is dropped) and `max_voices` (a play past it is
##   dropped). When a pool is full, the play takes the voice of the lowest priority (the oldest among equals) if that
##   one is not higher than its own; otherwise it is dropped.
## - Its own generator for the variant and the pitch: never randf()/randi() nor an AudioStreamRandomizer, which draw
##   from the global generator that MatchSeed seeds for the simulation.
## - Every request, played or dropped, goes to `sound_log` (the criterion of the cases and the lab).
## - Applies AudioPrefs (data/ui/audio_prefs.tres) to the AudioServer buses at start and on every change.
## - With the AudioGate closed (dedicated, room server, headless without --audio-probe) it creates and loads nothing:
##   no pool, no log, no prefs; every play returns false.
## Its clock advances with `_process` (process_mode ALWAYS), so cooldowns follow --fixed-fps and a paused match.

const PREFS_PATH := AudioPrefs.SHARED_PATH

@export_range(1, 128) var pool_3d_size := 32
@export_range(1, 64) var pool_2d_size := 8
@export var rng_seed := 5200
@export_range(1, 1024) var log_capacity := 64

## Null while the gate is closed.
var sound_log: SoundLog
var prefs: AudioPrefs

var _rng := RandomNumberGenerator.new()
var _voices_3d: Array[_Voice] = []
var _voices_2d: Array[_Voice] = []
## SoundCue -> clock of its last play.
var _last_play: Dictionary = {}
var _clock := 0.0
var _started := false


class _Voice:
	var player: Node
	var cue: SoundCue
	var started := 0.0

	func is_playing() -> bool:
		return cue != null and player.playing


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not AudioGate.is_open():
		set_process(false)
		return
	_started = true
	_rng.seed = rng_seed
	sound_log = SoundLog.new(log_capacity)
	for i in pool_3d_size:
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice3D_%d" % i
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_voices_3d.append(_make_voice(player))
	for i in pool_2d_size:
		var player := AudioStreamPlayer.new()
		player.name = "Voice2D_%d" % i
		add_child(player)
		_voices_2d.append(_make_voice(player))
	prefs = load(PREFS_PATH) as AudioPrefs
	if prefs == null:
		push_warning("SoundBus: falta %s; los buses quedan como están." % PREFS_PATH)
	else:
		prefs.changed.connect(apply_prefs)
		apply_prefs()


func _process(delta: float) -> void:
	_clock += delta


## True when this process plays sound (the gate was open at start).
func is_active() -> bool:
	return _started


## A cue in the world at `at`. False when it was dropped (gate closed, silent, cooldown, limits).
func play_3d(cue: SoundCue, at: Vector3, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _request(cue, true, at, emitter, event)


## A cue with no position (UI, voices, music stingers).
func play_2d(cue: SoundCue, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _request(cue, false, Vector3.ZERO, emitter, event)


## The cue of `event` in `sound_set` (or its fallback) at `at`; a missing set or cue is silence, without a log entry.
func play_event_3d(sound_set: SoundSet, event: StringName, at: Vector3, emitter: StringName = &"") -> bool:
	if not _started or sound_set == null:
		return false
	var cue := sound_set.cue(event)
	return cue != null and play_3d(cue, at, emitter, event)


func play_event_2d(sound_set: SoundSet, event: StringName, emitter: StringName = &"") -> bool:
	if not _started or sound_set == null:
		return false
	var cue := sound_set.cue(event)
	return cue != null and play_2d(cue, emitter, event)


## Voices playing now in a pool (3D or 2D), of `cue` or of any cue when null.
func active_voices(in_3d: bool, cue: SoundCue = null) -> int:
	var count := 0
	for voice in (_voices_3d if in_3d else _voices_2d):
		if voice.is_playing() and (cue == null or voice.cue == cue):
			count += 1
	return count


func pool_size(in_3d: bool) -> int:
	return (_voices_3d if in_3d else _voices_2d).size()


func stop_all() -> void:
	for voice in _voices_3d + _voices_2d:
		voice.player.stop()
		voice.cue = null


## Puts the preference on the AudioServer buses (a bus the layout lacks is skipped).
func apply_prefs() -> void:
	if prefs == null:
		return
	for bus in AudioPrefs.BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		AudioServer.set_bus_volume_db(index, prefs.db_for(prefs.volume(bus)))
		AudioServer.set_bus_mute(index, prefs.is_bus_silent(bus))


## Seeds this bus's own generator (the cases; a lab that wants the same variants every run).
func reseed(value: int) -> void:
	_rng.seed = value


func _make_voice(player: Node) -> _Voice:
	var voice := _Voice.new()
	voice.player = player
	return voice


func _request(cue: SoundCue, in_3d: bool, at: Vector3, emitter: StringName, event: StringName) -> bool:
	if not _started or cue == null:
		return false
	if cue.is_silent():
		sound_log.add(emitter, event, null, false, &"silent")
		return false
	if cue.cooldown_s > 0.0 and _last_play.has(cue) and _clock - float(_last_play[cue]) < cue.cooldown_s:
		sound_log.add(emitter, event, null, false, &"cooldown")
		return false
	if cue.max_voices > 0 and active_voices(in_3d, cue) >= cue.max_voices:
		sound_log.add(emitter, event, null, false, &"max_voices")
		return false
	var voice := _pick_voice(_voices_3d if in_3d else _voices_2d, cue.priority)
	if voice == null:
		sound_log.add(emitter, event, null, false, &"pool_full")
		return false
	var stream := _draw_stream(cue)
	var pitch := 1.0 + (_rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter) if cue.pitch_jitter > 0.0 else 0.0)
	var bus := cue.bus if AudioServer.get_bus_index(cue.bus) >= 0 else &"Master"
	var player := voice.player
	player.stop()
	player.stream = stream
	player.volume_db = cue.volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.bus = bus
	if in_3d:
		var p3: AudioStreamPlayer3D = player
		p3.max_distance = cue.max_distance_m
		p3.unit_size = cue.unit_size
		p3.global_position = at
	voice.cue = cue
	voice.started = _clock
	player.play()
	_last_play[cue] = _clock
	sound_log.add(emitter, event, stream, true)
	return true


## An idle voice, else the one of the lowest priority (oldest among equals) when it is not above `priority`, else null.
func _pick_voice(voices: Array[_Voice], priority: int) -> _Voice:
	var victim: _Voice = null
	for voice in voices:
		if not voice.is_playing():
			return voice
		if victim == null or voice.cue.priority < victim.cue.priority \
				or (voice.cue.priority == victim.cue.priority and voice.started < victim.started):
			victim = voice
	if victim != null and victim.cue.priority <= priority:
		return victim
	return null


func _draw_stream(cue: SoundCue) -> AudioStream:
	var usable: Array[AudioStream] = []
	for stream in cue.streams:
		if stream != null:
			usable.append(stream)
	return usable[_rng.randi_range(0, usable.size() - 1)] if usable.size() > 1 else usable[0]
