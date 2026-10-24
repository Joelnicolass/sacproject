@tool
class_name TargetEffect
extends Node3D

## What a SpellCarrier does to a body when something happens to it: on `arrived` (it got there; Death's every blow) or on `settled` (the wait is
## over) it applies its BodyEffect to the target, or, with a `reach`, to every creature whose box is inside that sphere around the carrier
## (Blind Rage's 30 m). One script for gibbing, killing, turning to the wizard's side or laying a state: the effect is a Resource inside the scene.
## It does not choose when (the carrier's signals), who the target is (the spell) nor what the effect does. Server (or solo) only.

enum When { ARRIVED, SETTLED }

@export var carrier: SpellCarrier
@export var when := When.SETTLED
@export var effect: BodyEffect
## Optional: the sphere (in the carrier's frame) of the bodies it reaches. Empty: only the target.
@export var reach: CollisionShape3D
## Who the reach takes: the creatures of any side (a wizard is not a victim of these spells).
@export var groups: Array[StringName] = [&"unit"]
## A flash and a sound at the carrier when it fires, once (a ParticleType under data/fx/, with its light). Optional.
@export var flash: ParticleType


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if carrier == null:
		warnings.append("Falta el SpellCarrier.")
	if effect == null:
		warnings.append("Falta el BodyEffect.")
	if reach != null and not reach.shape is SphereShape3D:
		warnings.append("`reach` necesita una forma esférica.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint() or carrier == null or not multiplayer.is_server():
		return
	(carrier.arrived if when == When.ARRIVED else carrier.settled).connect(_on_event)


## Metres around the carrier the reach covers (0: no reach).
func radius_m() -> float:
	return (reach.shape as SphereShape3D).radius if reach != null and reach.shape is SphereShape3D else 0.0


func _on_event(target: Node3D) -> void:
	if effect == null:
		return
	if flash != null:
		FxBus.broadcast(flash.bus_name(), carrier.global_position)
	if reach == null:
		effect.apply(carrier, target)
		return
	for body in SplashDamage.bodies_within(get_tree(), carrier.global_position, radius_m(), null, groups):
		effect.apply(carrier, body)
