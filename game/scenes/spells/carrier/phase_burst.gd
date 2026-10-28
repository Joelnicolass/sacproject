@tool
class_name PhaseBurst
extends Node

## Sprite bursts (FxBus types) at the carrier when its SpellCarrier enters a phase: the earth and rocks that fly up where Bovine Intervention's cow
## comes out of the land. `lift_m` raises the place above the carrier (the cow is born buried). It does not hurt and does not draw by itself (the
## types do). Server (or solo) only: FxBus carries the burst to every peer.

@export var carrier: SpellCarrier
@export var phase := SpellCarrier.Phase.FLYING
@export var effects: Array[ParticleType] = []
@export_range(-10.0, 10.0, 0.1, "suffix:m") var lift_m := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if carrier != null
		else PackedStringArray(["The SpellCarrier is missing."])
	)


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null or not multiplayer.is_server():
		return
	carrier.phase_changed.connect(_on_phase)


func _on_phase(now: SpellCarrier.Phase) -> void:
	if now != phase:
		return
	for type in effects:
		FxBus.broadcast(type, carrier.global_position + Vector3(0.0, lift_m, 0.0))
