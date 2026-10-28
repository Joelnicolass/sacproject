@tool
class_name SoundEmitter3D
extends AudioStreamPlayer3D

## A sound that belongs to a node of the world: a spell projectile when it is born, a building's loop, a ward's hum.
## - Its `cue` is a SoundCue dropped in the inspector (data/audio/cues/fireball_cast.tres, or one made right there); no
##   texts, no tables, no lookups.
## - One-shot (`loop` off): with `play_on_ready` it plays once when it enters the tree, through SoundBus's 3D pool at its
##   position (cooldown, max_voices, priority, the 32-voice cap). It does not follow the node.
## - Loop: it plays on this player (it follows the node) while `active` and within the cue's `max_distance_m` of the
##   listener, looking every `check_s`. SoundBus counts the loop in the 3D budget (`claim_loop`). Gapless when the stream
##   loops (the WAV import loop mode); a stream that does not loop is started again when it ends.
## - No cue or a silent cue: silence. A dedicated server and a headless bench (AudioGate closed) load the
##   scene and its cue file, and play nothing. Presentation only: it reads nothing of the simulation.
## Ref: the original's one-shots do not follow their node either.

## What this emitter sounds like. Empty = silence (the scene tree shows a warning).
@export var cue: SoundCue:
	set(value):
		cue = value
		update_configuration_warnings()
@export var loop := false
## One-shot: play once on entering the tree. Loop: claim it on entering the tree (in range and `active`).
@export var play_on_ready := true
## A loop sounds only while active (a manafount's jet or its Manalith; an altar standing). See set_active().
@export var active := true
## Real seconds between two looks at the range of a loop.
@export_range(0.05, 5.0, 0.05, "suffix:s") var check_s := 0.5
## Whose name goes to the SoundLog (empty = the parent).
@export var host: Node

var _open := false
var _left := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	_open = AudioGate.is_open()
	if not _open:
		set_process(false)
		return
	finished.connect(_on_finished)
	if not loop:
		set_process(false)
		if play_on_ready and active:
			play_once()
		return
	set_process(true)
	if play_on_ready:
		_look()


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = check_s
	_look()


func _exit_tree() -> void:
	if _open and loop:
		SoundBus.release_loop(self)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if cue != null else PackedStringArray(["Asigná `cue`: el SoundCue que suena (data/audio/cues/)."])


## Turns a loop on or off (a one-shot only remembers it for its next play_once).
func set_active(on: bool) -> void:
	active = on
	if _open and loop and is_inside_tree():
		_look()


## The one-shot now, at this node. False when it is silent or SoundBus dropped it.
func play_once() -> bool:
	if not _open or not is_inside_tree():
		return false
	return cue != null and SoundBus.play_3d(cue, global_position, emitter_name(), SoundEvent.CAST)


func is_looping() -> bool:
	return _open and SoundBus.holds_loop(self)


func emitter_name() -> StringName:
	var node := host if host != null else get_parent()
	return StringName(node.name) if node != null else StringName(name)


func _look() -> void:
	var found := cue if active else null
	var wanted := found != null and is_inside_tree() and _in_range(found)
	var held: bool = SoundBus.holds_loop(self)
	if wanted and not held:
		SoundBus.claim_loop(self, found, emitter_name(), SoundEvent.LOOP)
	elif not wanted and held:
		SoundBus.release_loop(self)


func _in_range(found: SoundCue) -> bool:
	var ear: Vector3 = SoundBus.listener_position()
	return ear == Vector3.INF or global_position.distance_to(ear) <= found.max_distance_m


## A stream that does not loop by itself starts again (a small gap; the original's loops are imported looping).
func _on_finished() -> void:
	if loop and SoundBus.holds_loop(self):
		play()
