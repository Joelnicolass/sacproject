@tool
class_name PhaseCue
extends Node

## A sound of a SpellCarrier tied to one of its phases: it plays once when the carrier enters
## `phase`, or (with `while_in`) it is a loop that sounds only while the carrier is in it. The
## SoundEmitter3D is a child of the carrier (the cue key and the table live in it). Presentation
## only: every peer plays its own from the replicated phase; a dedicated server plays nothing. It
## does not move the carrier.

@export var carrier: SpellCarrier
@export var phase := SpellCarrier.Phase.CASTING
@export var sound: SoundEmitter3D
## A loop: it sounds while the carrier is in `phase`.
@export var while_in := false


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if carrier != null and sound != null
		else PackedStringArray(["The SpellCarrier and the sound are missing."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null or sound == null:
		return
	carrier.phase_changed.connect(_on_phase)
	if carrier.phase == phase:
		_on_phase(phase)


func _on_phase(now: SpellCarrier.Phase) -> void:
	if while_in:
		sound.set_active(now == phase)
	elif now == phase:
		sound.play_once()
