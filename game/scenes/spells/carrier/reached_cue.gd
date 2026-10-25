@tool
class_name ReachedCue
extends Node

## A sound of a SpellCarrier played once when it reaches its soul (the turn of the Soul Mole's trip): the sound of the rock taking the soul.
## The SoundEmitter3D is a child of the carrier (the cue key and the table live in it) and plays at the carrier's place. Presentation only: it
## listens to the same `reached` signal SoulFetch does, so a client that does not run the trip hears nothing. It does not take the soul (SoulFetch).
## Ref: sacengine updateSoulMole, playSoundAt("ltss") (state.d:17990).

@export var carrier: SpellCarrier
@export var sound: SoundEmitter3D


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null and sound != null else PackedStringArray(["Faltan el SpellCarrier y el sonido."])


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null or sound == null:
		return
	carrier.reached.connect(_on_reached)


func _on_reached(_soul: Soul) -> void:
	sound.global_position = carrier.global_position
	sound.play_once()
