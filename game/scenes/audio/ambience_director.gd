@tool
class_name AmbienceDirector
extends Node

## The ambience of this process: the god's bed (a loop on the scene's own AudioStreamPlayer `bed`,
## bus of the cue: Ambience) and, every so often, a one-shot in 3D at a point around the listener
## (SoundBus.play_3d). When, which one-shot and where come from its own generator, never the global
## one.
## The set: `ambience` (a fixture in the lab), or the look's `ambience` of the GodType that `biome`
## applies (MatchBiome.applied(god)). No set (a god without one): silence. By night (the god's
## DayCycle at the match's sky clock, AtmosphereRules: the same hour the look shows) it plays the
## set's `night_one_shots` instead, when it has them.
## In the log: emitter `ambience`, event `bed` or `ambient`. With the AudioGate closed (dedicated,
## room server, headless) its player stays idle and it plays nothing. No RPC, nothing written to the
## simulation.

const EMITTER := &"ambience"

## The set there is before a biome applies. Empty: silence until a god comes.
@export var ambience: AmbienceSet
## The player of the bed loop (child of the scene).
@export var bed: AudioStreamPlayer
## Emits `applied(god)` with the GodType of the land (MatchBiome). Optional.
@export var biome: MatchBiome
@export var rng_seed := 5202

var ambience_set: AmbienceSet
var _open := false
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _next_at := INF
## The resolved one-shot cues of the set, by day and by night.
var _one_shots: Array[SoundCue] = []
var _night_shots: Array[SoundCue] = []
## The god's day (null = always day).
var _day: DayCycle


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and SoundBus.can_play() and bed != null
	if not _open:
		set_process(false)
		return
	_rng.seed = rng_seed
	SoundBus.adopt_channel(bed)
	if biome != null:
		biome.applied.connect(use_god)
	if ambience != null:
		use_ambience(ambience)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= _next_at:
		play_one_shot()


## The god's ambience (MatchBiome.applied).
func use_god(god: GodType) -> void:
	_day = god.look.day if god != null and god.look != null else null
	use_ambience(god.look.ambience if god != null and god.look != null else null)


## Starts the bed of `next_set` and schedules its first one-shot. No set: the bed stops, nothing
## plays.
func use_ambience(next_set: AmbienceSet) -> void:
	if not _open:
		return
	ambience_set = next_set
	_one_shots = one_shot_cues(ambience_set)
	_night_shots.clear()
	if ambience_set:
		_night_shots = playable(ambience_set.night_one_shots)
	restart_bed()
	_schedule()


## Starts the bed again (stops it when the set has none). False when nothing plays.
func restart_bed() -> bool:
	if not _open:
		return false
	bed.stop()
	var cue := bed_cue()
	if cue == null or not SoundBus.can_play():
		return false
	return SoundBus.play_on(bed, cue, EMITTER, SoundEvent.BED)


## The set's bed cue (null when it has none or it is silent).
func bed_cue() -> SoundCue:
	if ambience_set == null or ambience_set.bed == null or ambience_set.bed.is_silent():
		return null
	return ambience_set.bed


## True when the set has a one-shot to play.
func has_one_shots() -> bool:
	return not _one_shots.is_empty()


## One of the set's one-shots now, at a point around the listener; the next is scheduled. False when
## nothing played.
func play_one_shot() -> bool:
	_schedule()
	var shots: Array[SoundCue] = (
		_night_shots if not _night_shots.is_empty() and is_night() else _one_shots
	)
	if shots.is_empty() or not SoundBus.can_play():
		return false
	var at: Vector3 = SoundBus.listener_position()
	if at == Vector3.INF:
		return false
	var cue := shots[_rng.randi_range(0, shots.size() - 1)]
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(
		ambience_set.distance_m.x, maxf(ambience_set.distance_m.x, ambience_set.distance_m.y)
	)
	var height := _rng.randf_range(
		ambience_set.height_m.x, maxf(ambience_set.height_m.x, ambience_set.height_m.y)
	)
	var offset := Vector3(cos(angle) * distance, height, sin(angle) * distance)
	return SoundBus.play_3d(cue, at + offset, EMITTER, SoundEvent.AMBIENT)


## True while it is night on this land now.
func is_night() -> bool:
	return _day != null and AtmosphereRules.is_night(_day, MatchSky.now_s())


## The playable one-shots of `ambience_set` (the cues with a stream).
static func one_shot_cues(ambience_set: AmbienceSet) -> Array[SoundCue]:
	var none: Array[SoundCue] = []
	return playable(ambience_set.one_shots) if ambience_set != null else none


## The cues of `cues` that have a stream.
static func playable(cues: Array[SoundCue]) -> Array[SoundCue]:
	var out: Array[SoundCue] = []
	for cue in cues:
		if cue != null and not cue.is_silent():
			out.append(cue)
	return out


func _schedule() -> void:
	if ambience_set == null or (_one_shots.is_empty() and _night_shots.is_empty()):
		_next_at = INF
		return
	var low := maxf(ambience_set.interval_s.x, 0.1)
	_next_at = _clock + _rng.randf_range(low, maxf(low, ambience_set.interval_s.y))


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if bed != null
		else PackedStringArray(
			["Assign `bed` (the child AudioStreamPlayer): without it the background is silent."]
		)
	)
