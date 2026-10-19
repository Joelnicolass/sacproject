@tool
class_name BodySounds
extends Node

## RFC-052 052c (F362): the shared contract of UnitSounds and WizardSounds (the children that turn a body's replicated state
## into SoundEvents). It owns how an event finds its cue and the per-body limit of `damaged`; the subclasses only wire signals.
## - Where a cue comes from, in order: the body's own set (SoundLibrary, with its `fallback` chain: the melee set), then the
##   `aliases` of the event in that set (a fist creature has no `swing` but its melee set has `Xhit`), then the shared set
##   (`shared_set`, the world: `summon` lives there). No cue anywhere: silence, no log entry, no warning.
## - Everything is client presentation: it reads replicated state and signals, never writes the body, never draws from the
##   global generator (SoundBus has its own), never adds an RPC. With the AudioGate closed (dedicated, room server, headless)
##   it connects nothing and loads nothing.
## The set is resolved at play time (the tag may arrive after `_ready` on a client); SoundLibrary caches it.

## Event -> another key tried in the own set when the event has no cue there (one hop).
@export var aliases: Dictionary[StringName, StringName] = {&"swing": &"Xhit", &"shoot": &"swing"}
## The set asked last (SoundLibrary path under a root, "" = none): the original's world set holds `summon`.
@export var shared_set := "world"
## `damaged` plays at most once in this many seconds of game time per body (a poison tick or a swarm would chain it).
@export_range(0.0, 10.0, 0.1, "suffix:s") var damaged_every_s := 1.5
## Height over the body origin where the sound sits.
@export_range(0.0, 10.0, 0.1, "suffix:m") var height_m := 1.0

var _open := false
var _last_damaged_s := -INF


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open()


## The cue that answers `event` for this body now, or null (no set, no cue: silence). The lab asks it to know what to expect.
func cue_for(event: StringName) -> SoundCue:
	var own := own_set()
	var cue: SoundCue = own.cue(event) if own != null else null
	if cue == null and own != null and aliases.has(event):
		cue = own.cue(aliases[event])
	if cue == null and not shared_set.is_empty():
		var shared := SoundLibrary.sound_set(shared_set)
		cue = shared.cue(event) if shared != null else null
	return cue if cue != null and not cue.is_silent() else null


## Plays `event` at the body. False when it is silent or SoundBus dropped it.
func play(event: StringName) -> bool:
	if not _open:
		return false
	var cue := cue_for(event)
	var anchor := anchor()
	if cue == null or anchor == null or not anchor.is_inside_tree():
		return false
	return SoundBus.play_3d(cue, anchor.global_position + Vector3.UP * height_m, emitter_name(), event)


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


## The body's own set (subclasses: SoundLibrary.creature / wizard of the replicated tag).
func own_set() -> SoundSet:
	return null


## The node the sound follows (the body).
func anchor() -> Node3D:
	return null


## The emitter name of the SoundLog entries (the body's node name).
func emitter_name() -> StringName:
	var node := anchor()
	return StringName(node.name) if node != null else &""
