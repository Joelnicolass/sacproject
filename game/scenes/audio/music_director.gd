@tool
class_name MusicDirector
extends Node

## The music of this process. Two AudioStreamPlayer of the scene (TrackA, TrackB; bus of the set: Music) that crossfade in the
## set's `crossfade_s` (0.5 s); the track of a mood is drawn with its own generator (the battle one among battle1-5),
## never the global one. MusicMood decides the mood; this node only gathers its inputs and plays:
## - battle: `gauge` (CombatGauge.is_battle; it computes the intensity, not this node);
## - the result: Events.match_ended (won = the seat's slot is among the winners);
## - rituals (Events.ritual_started / ritual_ended, on every peer): one running within `ritual_radius_m` of the camera,
##   and the desecrations that involve the local side.
## The set: `music` (the menu's in boot.tscn, a fixture in the lab), or the look's `music` of the GodType that `biome` applies
## (MatchBiome.applied(god)); a god with no set of its own uses `default_music` (music/common.tres in the match).
## `menu` keeps the mood at calm. `victory` and `defeat` play once: the mood stays, the track is not restarted.
## Each change goes to SoundBus's log as emitter `music`, event = the mood. With the AudioGate closed (dedicated, room
## server, headless) its players stay idle and it plays nothing. No RPC, nothing written to the simulation.

signal mood_changed(mood: StringName)

const EMITTER := &"music"

## The set there is before a biome applies (the menu's, or the lab's). Empty: silence until a god comes.
@export var music: MusicSet
## What a god with no `music` of its own plays. Empty: silence.
@export var default_music: MusicSet
## The two players that crossfade (children of the scene).
@export var track_a: AudioStreamPlayer
@export var track_b: AudioStreamPlayer
## Emits `applied(god)` with the GodType of the land (MatchBiome). Optional.
@export var biome: MatchBiome
@export var gauge: CombatGauge
## Who looks at this screen (its slot decides the result and the desecrations). Empty: nobody (the menu in boot.tscn).
@export var seat: MpLocalSeat
## The camera the rituals are measured from. Optional: else the viewport's.
@export var camera: Camera3D
@export var menu := false
@export_range(1.0, 1000.0, 1.0, "suffix:m") var ritual_radius_m := 70.0
@export_range(0.05, 5.0, 0.05, "suffix:s") var look_every_s := 0.25
@export var rng_seed := 5201

var mood: StringName = &""
var music_set: MusicSet
var _open := false
var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _rng := RandomNumberGenerator.new()
var _look_left := 0.0
var _tweens: Array[Tween] = []
var _ended := false
var _winner_slots: Array[int] = []
## The rituals running on this peer (Events.ritual_started until ritual_ended).
var _rituals: Array[Ritual] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and SoundBus.can_play()
	if not _open:
		set_process(false)
		return
	_rng.seed = rng_seed
	Events.match_ended.connect(_on_match_ended)
	Events.ritual_started.connect(_on_ritual_started)
	Events.ritual_ended.connect(_on_ritual_ended)
	for player: AudioStreamPlayer in [track_a, track_b]:
		if player != null:
			SoundBus.adopt_channel(player)
			_players.append(player)
	if biome != null:
		biome.applied.connect(use_god)
	if gauge != null:
		gauge.battle_changed.connect(func(_on: bool) -> void: look())
	if music != null:
		use_music(music)


func _process(delta: float) -> void:
	_look_left -= delta
	if _look_left > 0.0:
		return
	_look_left = look_every_s
	look()


## The god's music (MatchBiome.applied).
func use_god(god: GodType) -> void:
	use_music(music_of(god))


## The set `god` plays: its look's `music`, else `default_music`; null when neither exists.
func music_of(god: GodType) -> MusicSet:
	return (
		god.look.music
		if god != null and god.look != null and god.look.music != null
		else default_music
	)


## Plays the mood of `next_set` from the start.
func use_music(next_set: MusicSet) -> void:
	if not _open:
		return
	music_set = next_set
	restart()


## Forgets the mood and looks again (the next track starts with a crossfade).
func restart() -> void:
	mood = &""
	look()


## Decides the mood now and switches when it changed (the gauge's flips and the lab call it so as not to wait).
func look() -> void:
	if not _open or music_set == null or _players.size() < 2 or not SoundBus.can_play():
		return
	var next := (
		MusicMood.CALM
		if menu
		else MusicMood.decide(_result(), _desecration(), _ritual_near(), _battle())
	)
	if next != mood:
		_switch(next)


## The stream `mood` plays now (null when silent).
func playing_stream() -> AudioStream:
	var player := _players[_front] if not _players.is_empty() else null
	return player.stream if player != null and player.playing else null


func _switch(next: StringName) -> void:
	mood = next
	mood_changed.emit(next)
	var tracks := music_set.tracks(next)
	var fade := music_set.crossfade_s
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	var old := _players[_front]
	if tracks.is_empty():
		_fade(old, _gain(old), 0.0, fade, true)
		SoundBus.log_dropped(EMITTER, next, &"silent")
		return
	var stream := tracks[_rng.randi_range(0, tracks.size() - 1)] if tracks.size() > 1 else tracks[0]
	_front = 1 - _front
	var player := _players[_front]
	player.stop()
	player.stream = stream
	player.bus = music_set.bus if AudioServer.get_bus_index(music_set.bus) >= 0 else &"Master"
	player.set_meta(&"base_db", music_set.volume_db)
	_set_gain(0.0, player)
	player.play()
	_fade(player, 0.0, 1.0, fade, false)
	if old.playing:
		_fade(old, _gain(old), 0.0, fade, true)
	SoundBus.log_played(EMITTER, next, stream)


func _fade(
	player: AudioStreamPlayer, from: float, to: float, seconds: float, stop_after: bool
) -> void:
	if seconds <= 0.0:
		_set_gain(to, player)
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_gain.bind(player), from, to, seconds)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens.append(tween)


## A linear gain 0..1 over the set's volume (a crossfade in dB would drop too fast).
func _set_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.set_meta(&"gain", gain)
	player.volume_db = float(player.get_meta(&"base_db", 0.0)) + linear_to_db(maxf(gain, 0.0001))


func _gain(player: AudioStreamPlayer) -> float:
	return float(player.get_meta(&"gain", 1.0)) if player.playing else 0.0


func _battle() -> bool:
	return gauge != null and gauge.is_battle()


func _on_match_ended(winner_slots: Array[int], _defeated_slots: Array[int]) -> void:
	_ended = true
	_winner_slots = winner_slots
	look()


func _on_ritual_started(ritual: Ritual) -> void:
	if not _rituals.has(ritual):
		_rituals.append(ritual)
		ritual.tree_exiting.connect(func() -> void: _rituals.erase(ritual), CONNECT_ONE_SHOT)
	look()


func _on_ritual_ended(ritual: Ritual, _completed: bool) -> void:
	_rituals.erase(ritual)
	look()


func _result() -> MusicMood.Result:
	var slot := seat.slot if seat != null else 0
	return MusicMood.result_of(_ended, _ended and slot > 0 and _winner_slots.has(slot), slot)


func _desecration() -> MusicMood.Desecration:
	var worst := MusicMood.Desecration.NONE
	var slot := seat.slot if seat != null else 0
	for ritual in _rituals:
		if ritual.is_running() and ritual.kind == Ritual.Kind.DESECRATE:
			worst = MusicMood.worst(
				worst, MusicMood.desecration_of(ritual.caster_slot, ritual.target_slot, slot)
			)
	return worst


func _ritual_near() -> bool:
	var view := camera if camera != null else get_viewport().get_camera_3d()
	if view == null or not view.is_inside_tree():
		return false
	var reach := ritual_radius_m * ritual_radius_m
	for ritual in _rituals:
		if (
			ritual.is_running()
			and ritual.center().distance_squared_to(view.global_position) <= reach
		):
			return true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if track_a == null or track_b == null:
		(
			out
			. append(
				"Assign `track_a` and `track_b` (the two child AudioStreamPlayers): without them there is no music."
			)
		)
	if seat == null and not menu:
		out.append(
			"Assign `seat` (the MpLocalSeat): without it it does not know who watches the result."
		)
	return out
