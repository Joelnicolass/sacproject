@tool
class_name SoundEmitter3D
extends AudioStreamPlayer3D

## RFC-052 052d (F363): a sound that belongs to a node of the world: a spell projectile on its spawn, a building's loop.
## - It names a key (`cue`) of a table (`source`, a SoundLibrary path: an FxSoundMap or a SoundSet), never a stream, and
##   resolves it lazily, only with the AudioGate open: a dedicated server, the room server and a headless bench load the
##   scene and no audio at all.
## - One-shot (`loop` off): with `play_on_ready` it plays once when it enters the tree, through SoundBus's 3D pool at its
##   position (cooldown, max_voices, priority, the 32-voice cap). It does not follow the node: the original does not either.
## - Loop: it plays on this player (it follows the node) while `active` and within the cue's `max_distance_m` of the
##   listener, looking every `check_s`. SoundBus counts the loop in the 3D budget (`claim_loop`). Gapless when the stream
##   loops (the WAV import loop mode); a stream that does not loop is started again when it ends.
## - No table, no key, a silent cue: silence, no warning. Presentation only: it reads nothing of the simulation.

## SoundLibrary path of the table (data/audio/<source>.tres, data/audio/custom/<source>.tres win key by key).
@export var source := "fx_sounds"
## The key of the cue in `source`.
@export var cue: StringName:
	set(value):
		cue = value
		_resolved = false
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
var _resolved := false
var _cue: SoundCue
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
	return PackedStringArray() if not cue.is_empty() else PackedStringArray(["Asigná `cue`: la clave del sonido en `source`."])


## Turns a loop on or off (a one-shot only remembers it for its next play_once).
func set_active(on: bool) -> void:
	active = on
	if _open and loop and is_inside_tree():
		_look()


## The one-shot now, at this node. False when it is silent or SoundBus dropped it.
func play_once() -> bool:
	if not _open or not is_inside_tree():
		return false
	var found := resolved_cue()
	return found != null and SoundBus.play_3d(found, global_position, emitter_name(), SoundEvent.CAST)


## Lets go of the loop and looks again with the table resolved anew (SoundLibrary's roots changed: the lab).
func restart() -> void:
	if not _open:
		return
	_resolved = false
	if loop:
		SoundBus.release_loop(self)
		_left = check_s
		_look()


## The cue of `cue` in `source`, or null; looked up once (only with the gate open).
func resolved_cue() -> SoundCue:
	if not _open:
		return null
	if not _resolved:
		_resolved = true
		_cue = SoundBus.lookup(source, cue)
	return _cue


func is_looping() -> bool:
	return _open and SoundBus.holds_loop(self)


func emitter_name() -> StringName:
	var node := host if host != null else get_parent()
	return StringName(node.name) if node != null else StringName(name)


func _look() -> void:
	var found := resolved_cue() if active else null
	var wanted := found != null and is_inside_tree() and _in_range(found)
	var held := SoundBus.holds_loop(self)
	if wanted and not held:
		SoundBus.claim_loop(self, found, emitter_name(), SoundEvent.LOOP)
	elif not wanted and held:
		SoundBus.release_loop(self)


func _in_range(found: SoundCue) -> bool:
	var ear := SoundBus.listener_position()
	return ear == Vector3.INF or global_position.distance_to(ear) <= found.max_distance_m


## A stream that does not loop by itself starts again (a small gap; the original's loops are imported looping).
func _on_finished() -> void:
	if loop and SoundBus.holds_loop(self):
		play()
