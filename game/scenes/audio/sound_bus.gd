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
## RFC-052 052d (F363):
## - What an FX sounds like is FxSounds, a child of the SoundBus scene: it listens to FxBus.played and calls play_3d.
## - Loops (SoundEmitter3D): `claim_loop` plays a cue on the emitter's own player (it follows its node) and counts it in
##   the 3D budget: pooled 3D voices + loops never pass `pool_3d_size`. A claim with the budget full takes the pooled
##   voice of the lowest priority (if not above its own); `max_loops_3d` caps the loops alone.
## - `listener`: the node the player hears from (ListenerFocus sets it); emitters measure their range from it.
## RFC-052 052e (F364): `play_on` plays a cue on a voice channel's own player (CommandVoice, AdvisorVoice); the channel
## decides what cuts what, the bus only draws the variant, configures and logs.
## RFC-052 052f (F365): `log_played` and `adopt_channel` for a player that picks its own stream (MusicDirector draws the
## battle track with its own generator and crossfades two players): the entry goes to the log and stop_all stops it.
## RFC-052 052h (F367): the click of every pressed button is UiClickSounds, a child of the SoundBus scene: it calls play_2d.

const PREFS_PATH := AudioPrefs.SHARED_PATH

@export_range(1, 128) var pool_3d_size := 32
@export_range(1, 64) var pool_2d_size := 8
@export var rng_seed := 5200
@export_range(1, 1024) var log_capacity := 64
## Loops playing at once (SoundEmitter3D: fountains, manaliths, altars); they also count in `pool_3d_size`.
@export_range(0, 64) var max_loops_3d := 8

## The child that turns FxBus's bursts and beams into sounds (sound_bus.tscn).
@export var fx_sounds: FxSounds
## The child that clicks for every pressed button (sound_bus.tscn).
@export var ui_clicks: UiClickSounds

## Null while the gate is closed.
var sound_log: SoundLog
var prefs: AudioPrefs
## Where the player hears from (ListenerFocus); null = the viewport's camera.
var listener: Node3D

var _rng := RandomNumberGenerator.new()
var _voices_3d: Array[_Voice] = []
var _voices_2d: Array[_Voice] = []
## SoundEmitter3D players holding a loop.
var _loops: Array[_Voice] = []
## Voice channel players that went through play_on (stop_all stops them too).
var _channels: Array[AudioStreamPlayer] = []
## SoundCue -> clock of its last play.
var _last_play: Dictionary = {}
var _clock := 0.0
var _started := false
## After shutdown(): nothing plays nor claims (a run about to quit).
var _closed := false


class _Voice:
	var player: Node
	var cue: SoundCue
	var started := 0.0

	func is_playing() -> bool:
		return cue != null and is_instance_valid(player) and player.playing


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


## The cue of `key` in the first of SoundLibrary's roots whose `rel` answers it (a SoundSet), or null.
func lookup(rel: String, key: StringName) -> SoundCue:
	if not _started or key.is_empty():
		return null
	for found in SoundLibrary.find_all(rel):
		var table := found as SoundSet
		var cue := table.cue(key) if table != null else null
		if cue != null and not cue.is_silent():
			return cue
	return null


## Where the player hears from: `listener`, else the viewport's camera; INF when there is neither.
func listener_position() -> Vector3:
	if is_instance_valid(listener) and listener.is_inside_tree():
		return listener.global_position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera.global_position if camera != null else Vector3.INF


## A cue in the world at `at`. False when it was dropped (gate closed, silent, cooldown, limits).
func play_3d(cue: SoundCue, at: Vector3, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _request(cue, true, at, emitter, event)


## A cue with no position (UI, voices, music stingers).
func play_2d(cue: SoundCue, emitter: StringName = &"", event: StringName = &"") -> bool:
	return _request(cue, false, Vector3.ZERO, emitter, event)


## A cue on a player the caller owns: a voice channel (CommandVoice, AdvisorVoice, 052e) that says one line at a time and
## decides itself what cuts what. The player is stopped and reconfigured (a variant and a pitch from this bus's generator);
## it does not count in the 2D pool, the cue's `cooldown_s` still applies. False (and a log entry) when it was dropped.
func play_on(player: AudioStreamPlayer, cue: SoundCue, emitter: StringName = &"", event: StringName = &"") -> bool:
	if not _started or _closed or cue == null or player == null:
		return false
	if cue.is_silent():
		sound_log.add(emitter, event, null, false, &"silent")
		return false
	if cue.cooldown_s > 0.0 and _last_play.has(cue) and _clock - float(_last_play[cue]) < cue.cooldown_s:
		sound_log.add(emitter, event, null, false, &"cooldown")
		return false
	if not _channels.has(player):
		for i in range(_channels.size() - 1, -1, -1):
			if not is_instance_valid(_channels[i]):
				_channels.remove_at(i)
		_channels.append(player)
	var stream := _draw_stream(cue)
	player.stop()
	_configure(player, cue, stream, false)
	player.play()
	_last_play[cue] = _clock
	sound_log.add(emitter, event, stream, true)
	return true


## A stream a player of the caller's started on its own (MusicDirector): a played entry only.
func log_played(emitter: StringName, event: StringName, stream: AudioStream) -> void:
	if _started:
		sound_log.add(emitter, event, stream, true)


## A player of the caller's that stop_all() (and shutdown()) stops too.
func adopt_channel(player: AudioStreamPlayer) -> void:
	if _started and player != null and not _channels.has(player):
		_channels.append(player)


## False before start (gate closed) and after shutdown(): nothing may start playing.
func can_play() -> bool:
	return _started and not _closed


## A request a voice channel turned down before it reached a player (queue full, a repeated line): a log entry only.
func log_dropped(emitter: StringName, event: StringName, reason: StringName) -> void:
	if _started:
		sound_log.add(emitter, event, null, false, reason)


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


## Voices playing now (3D: the pool and the loops; 2D: the pool), of `cue` or of any cue when null.
func active_voices(in_3d: bool, cue: SoundCue = null) -> int:
	var count := 0
	for voice in (_voices_3d + _loops if in_3d else _voices_2d):
		if voice.is_playing() and (cue == null or voice.cue == cue):
			count += 1
	return count


## Loops playing now.
func active_loops() -> int:
	var count := 0
	for voice in _loops:
		if voice.is_playing():
			count += 1
	return count


## Plays `cue` in a loop on `player` (a SoundEmitter3D: it keeps its node's position) while it holds the claim. False
## (and a log entry) when it was refused: silent, `max_loops_3d`, the cue's `max_voices`, or a full 3D budget whose
## pooled voices are all above its priority. Already held: true, nothing changes.
func claim_loop(player: AudioStreamPlayer3D, cue: SoundCue, emitter: StringName = &"", event: StringName = SoundEvent.LOOP) -> bool:
	if not _started or _closed or cue == null or player == null:
		return false
	if holds_loop(player):
		return true
	if cue.is_silent():
		sound_log.add(emitter, event, null, false, &"silent")
		return false
	if _loops.size() >= max_loops_3d:
		sound_log.add(emitter, event, null, false, &"loops_full")
		return false
	if cue.max_voices > 0 and active_voices(true, cue) >= cue.max_voices:
		sound_log.add(emitter, event, null, false, &"max_voices")
		return false
	if active_voices(true) >= _voices_3d.size():
		var victim := _pick_voice(_voices_3d, cue.priority, 0)
		if victim == null:
			sound_log.add(emitter, event, null, false, &"pool_full")
			return false
		victim.player.stop()
		victim.cue = null
	var stream := _draw_stream(cue)
	_configure(player, cue, stream, true)
	var voice := _make_voice(player)
	voice.cue = cue
	voice.started = _clock
	_loops.append(voice)
	player.play()
	sound_log.add(emitter, event, stream, true)
	return true


## Lets go of the loop of `player` and stops it.
func release_loop(player: AudioStreamPlayer3D) -> void:
	for i in range(_loops.size() - 1, -1, -1):
		if _loops[i].player == player:
			_loops.remove_at(i)
	if is_instance_valid(player):
		player.stop()


func holds_loop(player: AudioStreamPlayer3D) -> bool:
	for voice in _loops:
		if voice.player == player:
			return true
	return false


func pool_size(in_3d: bool) -> int:
	return (_voices_3d if in_3d else _voices_2d).size()


## Stops every voice and lets go of every loop (an emitter in range claims its loop again on its next look).
func stop_all() -> void:
	for voice in _voices_3d + _voices_2d:
		voice.player.stop()
		voice.cue = null
	for voice in _loops:
		if is_instance_valid(voice.player):
			voice.player.stop()
	_loops.clear()
	for player in _channels:
		if is_instance_valid(player):
			player.stop()


## stop_all() and nothing plays or claims after it: a run about to quit (the audio server needs a moment to let go of
## its playbacks, and a loop claimed in that moment would leak at exit).
func shutdown() -> void:
	stop_all()
	_closed = true


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
	if not _started or _closed or cue == null:
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
	var budget := _voices_3d.size() - active_loops() if in_3d else _voices_2d.size()
	var voice := _pick_voice(_voices_3d if in_3d else _voices_2d, cue.priority, budget)
	if voice == null:
		sound_log.add(emitter, event, null, false, &"pool_full")
		return false
	var stream := _draw_stream(cue)
	var player := voice.player
	player.stop()
	_configure(player, cue, stream, in_3d)
	if in_3d:
		(player as AudioStreamPlayer3D).global_position = at
	voice.cue = cue
	voice.started = _clock
	player.play()
	_last_play[cue] = _clock
	sound_log.add(emitter, event, stream, true)
	return true


## An idle voice while fewer than `budget` play, else the playing one of the lowest priority (oldest among equals) when
## it is not above `priority`, else null.
func _pick_voice(voices: Array[_Voice], priority: int, budget: int) -> _Voice:
	var victim: _Voice = null
	var idle: _Voice = null
	var playing := 0
	for voice in voices:
		if not voice.is_playing():
			if idle == null:
				idle = voice
			continue
		playing += 1
		if victim == null or voice.cue.priority < victim.cue.priority \
				or (voice.cue.priority == victim.cue.priority and voice.started < victim.started):
			victim = voice
	if idle != null and playing < budget:
		return idle
	if victim != null and victim.cue.priority <= priority:
		return victim
	return null


## Puts a cue's stream, volume, pitch (with its jitter, from this bus's generator), bus and 3D falloff on a player.
func _configure(player: Node, cue: SoundCue, stream: AudioStream, in_3d: bool) -> void:
	var pitch := 1.0 + (_rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter) if cue.pitch_jitter > 0.0 else 0.0)
	player.stream = stream
	player.volume_db = cue.volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.bus = cue.bus if AudioServer.get_bus_index(cue.bus) >= 0 else &"Master"
	if in_3d:
		var p3: AudioStreamPlayer3D = player
		p3.max_distance = cue.max_distance_m
		p3.unit_size = cue.unit_size


func _draw_stream(cue: SoundCue) -> AudioStream:
	var usable: Array[AudioStream] = []
	for stream in cue.streams:
		if stream != null:
			usable.append(stream)
	return usable[_rng.randi_range(0, usable.size() - 1)] if usable.size() > 1 else usable[0]
