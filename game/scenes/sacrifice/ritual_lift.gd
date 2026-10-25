@tool
class_name RitualLift
extends Node

## The captive goes up to the hanging point over the site, slowing in so it is there when the setup ends, and is held there after.
## What it does not do: decide when the ritual runs (Ritual calls `step` once a tick, before Watch) or move the doctors.
## Take this node out of ritual.tscn and the creature stays where it was taken.
## Ref: sacengine state.d:15928-15930.

@export var ritual: Ritual


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que levanta a la criatura.")
	return warnings


func step(delta: float) -> void:
	var creature := ritual.creature
	if not is_instance_valid(creature) or ritual.rules == null:
		return
	var hang := SacrificeFacts.of_rules(ritual.rules).hang_up_m
	var target := ritual.center() + Vector3(0.0, hang, 0.0)
	var left := maxf(ritual.rules.ritual_setup_s - ritual.elapsed, delta)
	creature.global_position = creature.global_position.lerp(target, clampf(delta / left, 0.0, 1.0))
	creature.velocity = Vector3.ZERO
