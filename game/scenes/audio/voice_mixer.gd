class_name VoiceMixer
extends RefCounted

## Decides what plays on SoundBus's players: which voice a request takes, what is dropped and why, and the loops of the
## emitters. A cue too soon after its last play, or past its `max_voices`, is dropped; with the pool full, a play takes the
## voice of the lowest priority unless that one is above it. Every request, played or dropped, goes to `sound_log`.
## It starts nothing before `live` is true (the bus sets it when the AudioGate is open) and nothing after `closed`.

var playback := CuePlayback.new()
var pool_3d := VoicePool.new()
var pool_2d := VoicePool.new()
var loops := VoicePool.new()
var sound_log: SoundLog
var live := false
var closed := false
## Loops playing at once; they also count in the 3D pool's budget.
var max_loops := 8

## Players of the callers' voice channels (stop_all stops them too).
var _channels: Array[AudioStreamPlayer] = []


func can_play() -> bool:
	return live and not closed


## A cue in the pool of the world or of the UI. False when it was dropped.
func request(cue: SoundCue, in_3d: bool, at: Vector3, emitter: StringName, event: StringName) -> bool:
	if not can_play() or cue == null:
		return false
	var reason := playback.refusal(cue, active_voices(in_3d, cue))
	var pool := pool_3d if in_3d else pool_2d
	var voice: VoicePool.Voice = pool.pick(cue.priority, pool.size() - (loops.active() if in_3d else 0)) if reason.is_empty() else null
	if reason.is_empty() and voice == null:
		reason = &"pool_full"
	if not reason.is_empty():
		return drop(emitter, event, reason)
	var stream := playback.draw_stream(cue)
	voice.player.stop()
	playback.configure(voice.player, cue, stream, in_3d)
	if in_3d:
		(voice.player as AudioStreamPlayer3D).global_position = at
	voice.cue = cue
	voice.started = playback.clock
	voice.player.play()
	playback.mark_played(cue)
	sound_log.add(emitter, event, stream, true)
	return true


## A cue on a player the caller owns (a voice channel): it is stopped and reconfigured; it does not count in the 2D pool.
func play_on(player: AudioStreamPlayer, cue: SoundCue, emitter: StringName, event: StringName) -> bool:
	if not can_play() or cue == null or player == null:
		return false
	var reason := playback.refusal(cue)
	if not reason.is_empty():
		return drop(emitter, event, reason)
	adopt_channel(player)
	var stream := playback.draw_stream(cue)
	player.stop()
	playback.configure(player, cue, stream, false)
	player.play()
	playback.mark_played(cue)
	sound_log.add(emitter, event, stream, true)
	return true


func adopt_channel(player: AudioStreamPlayer) -> void:
	if live and player != null and not _channels.has(player):
		for i in range(_channels.size() - 1, -1, -1):
			if not is_instance_valid(_channels[i]):
				_channels.remove_at(i)
		_channels.append(player)


## Plays `cue` in a loop on `player` (a SoundEmitter3D keeps its node's position) while it holds the claim. False (and a log
## entry) when refused: silent, `max_loops`, the cue's `max_voices`, or a full 3D budget of voices above its priority.
func claim_loop(player: AudioStreamPlayer3D, cue: SoundCue, emitter: StringName, event: StringName) -> bool:
	if not can_play() or cue == null or player == null:
		return false
	if loops.holds(player):
		return true
	var reason := playback.refusal(cue, -1, false)
	if reason.is_empty() and loops.size() >= max_loops:
		reason = &"loops_full"
	if reason.is_empty():
		reason = playback.refusal(cue, active_voices(true, cue), false)
	if reason.is_empty() and active_voices(true) >= pool_3d.size():
		var victim := pool_3d.pick(cue.priority, 0)
		if victim == null:
			reason = &"pool_full"
		else:
			victim.player.stop()
			victim.cue = null
	if not reason.is_empty():
		return drop(emitter, event, reason)
	var stream := playback.draw_stream(cue)
	playback.configure(player, cue, stream, true)
	loops.add(player, cue, playback.clock)
	player.play()
	sound_log.add(emitter, event, stream, true)
	return true


## Voices playing now (3D: the pool and the loops; 2D: the pool), of `cue` or of any cue when null.
func active_voices(in_3d: bool, cue: SoundCue = null) -> int:
	return pool_3d.active(cue) + loops.active(cue) if in_3d else pool_2d.active(cue)


## Stops every voice and lets go of every loop (an emitter in range claims its loop again on its next look).
func stop_all() -> void:
	pool_3d.stop_all()
	pool_2d.stop_all()
	loops.stop_all(true)
	for player in _channels:
		if is_instance_valid(player):
			player.stop()


## A request turned down: a log entry with the reason, and false.
func drop(emitter: StringName, event: StringName, reason: StringName) -> bool:
	sound_log.add(emitter, event, null, false, reason)
	return false
