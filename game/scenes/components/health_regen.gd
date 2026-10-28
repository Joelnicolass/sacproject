@tool
class_name HealthRegen
extends Node

## Gives a body's health back at a steady pace: a bar that was empty is full again after `refill_s`
## seconds. Take the node out and the body stops healing. Does not decide who may heal or when: only
## the side with authority changes Health.

@export var health: Health
## Seconds to go from 0 to full. 0 = off.
@export_range(0.0, 600.0, 1.0, "or_greater", "suffix:s") var refill_s := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if health != null
		else PackedStringArray(["Assign to `health` the health that regenerates."])
	)


func _physics_process(delta: float) -> void:
	if (
		Engine.is_editor_hint()
		or health == null
		or refill_s <= 0.0
		or health.is_dead()
		or health.is_full()
	):
		return
	health.heal(health.maximum / refill_s * delta)
