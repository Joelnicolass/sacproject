@tool
class_name AmbienceDirector
extends Node

## RFC-052 052g (F366): the ambience of this process: the god's bed (a loop on its own AudioStreamPlayer, bus of the cue:
## Ambience) and, every so often, a one-shot in 3D at a point around the listener (SoundBus.play_3d), as the original's
## `A*` ambient sounds. When, which one-shot and where come from its own generator, never the global one.
## The set: `set_path` (SoundLibrary: "ambience/james" in the lab), or the god of `biome` (MatchBiome.applied(god) ->
## "ambience/<god>"). No set (a god without one, the original not imported): silence.
## In the log: emitter `ambience`, event `bed` or `ambient`. With the AudioGate closed (dedicated, room server, headless)
## it creates no player and loads nothing. No RPC, nothing written to the simulation.

const EMITTER := &"ambience"

## SoundLibrary path of the set when there is no `biome` (or before it applies).
@export var set_path := ""
## Emits `applied(god: StringName)` (MatchBiome). Optional.
@export var biome: Node
@export var rng_seed := 5202

var ambience_set: AmbienceSet
var _open := false
var _bed: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _next_at := INF
## The resolved one-shot cues of the set.
var _one_shots: Array[SoundCue] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and SoundBus.can_play()
	if not _open:
		set_process(false)
		return
	_rng.seed = rng_seed
	_bed = AudioStreamPlayer.new()
	_bed.name = "Bed"
	add_child(_bed)
	SoundBus.adopt_channel(_bed)
	if biome != null and biome.has_signal("applied"):
		biome.connect("applied", use_god)
	if not set_path.is_empty():
		use_set(set_path)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= _next_at:
		play_one_shot()


## The god's ambience (MatchBiome.applied).
func use_god(god: StringName) -> void:
	use_set("ambience/%s" % god)


## Loads the set of `path`, starts its bed and schedules the first one-shot. No set: the bed stops, nothing plays.
func use_set(path: String) -> void:
	if not _open:
		return
	set_path = path
	ambience_set = SoundLibrary.find(path) as AmbienceSet
	_one_shots = one_shot_cues(ambience_set)
	restart_bed()
	_schedule()


## Starts the bed again (stops it when the set has none). False when nothing plays.
func restart_bed() -> bool:
	if not _open:
		return false
	_bed.stop()
	var cue := bed_cue()
	if cue == null or not SoundBus.can_play():
		return false
	return SoundBus.play_on(_bed, cue, EMITTER, SoundEvent.BED)


## The set's bed cue (null when it has none or it is silent).
func bed_cue() -> SoundCue:
	if ambience_set == null or ambience_set.bed == null or ambience_set.bed.is_silent():
		return null
	return ambience_set.bed


## True when the set has a one-shot to play.
func has_one_shots() -> bool:
	return not _one_shots.is_empty()


## One of the set's one-shots now, at a point around the listener; the next is scheduled. False when nothing played.
func play_one_shot() -> bool:
	_schedule()
	if _one_shots.is_empty() or not SoundBus.can_play():
		return false
	var at := SoundBus.listener_position()
	if at == Vector3.INF:
		return false
	var cue := _one_shots[_rng.randi_range(0, _one_shots.size() - 1)]
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(ambience_set.distance_m.x, maxf(ambience_set.distance_m.x, ambience_set.distance_m.y))
	var height := _rng.randf_range(ambience_set.height_m.x, maxf(ambience_set.height_m.x, ambience_set.height_m.y))
	var offset := Vector3(cos(angle) * distance, height, sin(angle) * distance)
	return SoundBus.play_3d(cue, at + offset, EMITTER, SoundEvent.AMBIENT)


## The playable one-shots of `ambience`: its keys looked up in `one_shot_source` over SoundLibrary's roots, then its own.
static func one_shot_cues(ambience: AmbienceSet) -> Array[SoundCue]:
	var out: Array[SoundCue] = []
	if ambience == null:
		return out
	for key in ambience.one_shot_keys:
		var cue := SoundBus.lookup(ambience.one_shot_source, key)
		if cue != null:
			out.append(cue)
	for cue in ambience.one_shots:
		if cue != null and not cue.is_silent():
			out.append(cue)
	return out


func _schedule() -> void:
	if ambience_set == null or _one_shots.is_empty():
		_next_at = INF
		return
	var low := maxf(ambience_set.interval_s.x, 0.1)
	_next_at = _clock + _rng.randf_range(low, maxf(low, ambience_set.interval_s.y))
