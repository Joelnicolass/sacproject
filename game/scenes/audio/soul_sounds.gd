@tool
class_name SoulSounds
extends BodySounds

## Child of souls/soul.tscn. `collected_cue` when a wizard takes the soul: its replicated `state` becomes COLLECTING
## (Soul.state_changed, the setter, on every peer). A soul that leaves
## the tree while COLLECTING and never played (its state and its despawn arrived together) plays then. Eaten (DEVOURING),
## burst or revived: silence. A Convert sounds through RitualSounds when it ends. No RPC, nothing written. With the AudioGate
## closed it connects nothing. Remove the node to silence every soul.

@export var soul: Soul:
	set(value):
		soul = value
		update_configuration_warnings()

## The sound of the soul being taken (assigned in soul.tscn).
@export var collected_cue: SoundCue

var _played := false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint() or not _open or soul == null:
		return
	soul.state_changed.connect(_on_state_changed)
	soul.tree_exiting.connect(_on_leaving)


func anchor() -> Node3D:
	return soul


## The cue that answers `event`: `collected_cue` for the soul being taken.
func default_cue(event: StringName) -> SoundCue:
	return collected_cue if event == SoundEvent.SOUL else null


func _on_state_changed(_was: Soul.State, now: Soul.State) -> void:
	if now == Soul.State.COLLECTING and not _played:
		_played = true
		play(SoundEvent.SOUL)


func _on_leaving() -> void:
	if soul.state == Soul.State.COLLECTING and not _played:
		_played = true
		play(SoundEvent.SOUL)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if soul != null else PackedStringArray(["Assign in `soul` the Soul that sounds."])
