class_name CuePlayback
extends RefCounted

## How one cue plays: whether it may play now (silent, too soon after its last play, too many at once), which of its variants
## and what pitch, and how a player is set up for it. It has its own random generator and clock: never randf()/randi() nor an
## AudioStreamRandomizer, which draw from the global generator that MatchSeed seeds for the simulation. It starts nothing.

## Game time in seconds; the owner advances it, so cooldowns follow --fixed-fps and a paused match.
var clock := 0.0

var _rng := RandomNumberGenerator.new()
## SoundCue -> clock of its last play.
var _last_play: Dictionary = {}


func reseed(value: int) -> void:
	_rng.seed = value


## Why `cue` may not play now (&"silent", &"cooldown", &"max_voices"), or &"" when it may. `active` is how many of its
## voices play; a negative one skips that limit.
func refusal(cue: SoundCue, active := -1, with_cooldown := true) -> StringName:
	if cue.is_silent():
		return &"silent"
	if with_cooldown and cue.cooldown_s > 0.0 and _last_play.has(cue) and clock - float(_last_play[cue]) < cue.cooldown_s:
		return &"cooldown"
	if cue.max_voices > 0 and active >= cue.max_voices:
		return &"max_voices"
	return &""


func mark_played(cue: SoundCue) -> void:
	_last_play[cue] = clock


func draw_stream(cue: SoundCue) -> AudioStream:
	var usable: Array[AudioStream] = []
	for stream in cue.streams:
		if stream != null:
			usable.append(stream)
	return usable[_rng.randi_range(0, usable.size() - 1)] if usable.size() > 1 else usable[0]


## Puts a cue's stream, volume, pitch (with its jitter), bus and 3D falloff on a player.
func configure(player: Node, cue: SoundCue, stream: AudioStream, in_3d: bool) -> void:
	var pitch := 1.0 + (_rng.randf_range(-cue.pitch_jitter, cue.pitch_jitter) if cue.pitch_jitter > 0.0 else 0.0)
	player.stream = stream
	player.volume_db = cue.volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.bus = cue.bus if AudioServer.get_bus_index(cue.bus) >= 0 else &"Master"
	if in_3d:
		var p3: AudioStreamPlayer3D = player
		p3.max_distance = cue.max_distance_m
		p3.unit_size = cue.unit_size
