@tool
class_name BodySounds
extends Node

## The shared part of UnitSounds and WizardSounds, the children that turn a body's replicated state
## into sound events. It owns how an event finds its cue and the per-body limit of `damaged`; the
## subclasses only wire the signals. It does not decide what the body sounds like: that is the
## `sounds` set of its look (BodyLook, the appearance scene next to its body scene).
## - Where a cue comes from: the body's own set (`BodyMount.sounds()`, with its `fallback` chain:
##   the melee set), then `default_cue` (UnitSounds: the summon cue every creature shares). No cue
##   anywhere: silence, no log entry, no warning.
## - Everything is client presentation: it reads replicated state and signals, never writes the
##   body, never draws from the global generator (SoundBus has its own), never adds an RPC. With the
##   AudioGate closed (dedicated, room server, headless) it connects nothing and plays nothing.
## The set is read at play time (the type may arrive after `_ready` on a client).

## `damaged` plays at most once in this many seconds of game time per body (a poison tick or a swarm
## would chain it).
@export_range(0.0, 10.0, 0.1, "suffix:s") var damaged_every_s := 1.5
## Height over the body origin where the sound sits.
@export_range(0.0, 10.0, 0.1, "suffix:m") var height_m := 1.0

var _open := false
var _last_damaged_s := -INF


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open()


## The cue that answers `event` for this body now, or null (no set, no cue: silence). The lab asks
## it to know what to expect.
func cue_for(event: StringName) -> SoundCue:
	return resolve(own_set(), event, default_cue(event))


## The cue `sounds` gives for `event` (its fallback chain), else `otherwise`; null when there is
## none or it is silent. Static so the command voice and the migration check ask the same rule.
static func resolve(sounds: SoundSet, event: StringName, otherwise: SoundCue = null) -> SoundCue:
	var found: SoundCue = sounds.cue(event) if sounds != null else null
	if found == null:
		found = otherwise
	return found if found != null and not found.is_silent() else null


## Plays `event` at the body. False when it is silent or SoundBus dropped it.
func play(event: StringName) -> bool:
	if not _open:
		return false
	var cue := cue_for(event)
	var anchor := anchor()
	if cue == null or anchor == null or not anchor.is_inside_tree():
		return false
	return SoundBus.play_3d(
		cue, anchor.global_position + Vector3.UP * height_m, emitter_name(), event
	)


## `damaged`, at most once every `damaged_every_s` of game time.
func play_damaged() -> bool:
	if not _open:
		return false
	var now := game_seconds()
	if now - _last_damaged_s < damaged_every_s or cue_for(SoundEvent.DAMAGED) == null:
		return false
	_last_damaged_s = now
	return play(SoundEvent.DAMAGED)


## Game time: physics ticks over the tick rate (follows --fixed-fps; real time would not).
static func game_seconds() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## The body's own set (subclasses: `sounds` of its CreatureType or WizardType).
func own_set() -> SoundSet:
	return null


## The cue an event gets when the own set has none (subclasses: the creature's summon).
func default_cue(_event: StringName) -> SoundCue:
	return null


## The node the sound follows (the body).
func anchor() -> Node3D:
	return null


## The emitter name of the SoundLog entries (the body's node name).
func emitter_name() -> StringName:
	var node := anchor()
	return StringName(node.name) if node != null else &""
