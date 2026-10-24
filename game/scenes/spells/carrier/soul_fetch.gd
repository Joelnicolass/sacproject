@tool
class_name SoulFetch
extends Node

## At the turn of its SpellCarrier it takes the soul: the soul lets go of its corpse (which dissolves), prefers the wizard's side
## and follows the carrier home. It does not move anything itself nor decide who collects the soul at the end (SoulSystem does).
## Server (or solo) only.

@export var carrier: SpellCarrier


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null:
		return
	carrier.reached.connect(_take)


func _take(soul: Soul) -> void:
	soul.release_to(carrier.from_slot, carrier)
