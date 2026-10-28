@tool
class_name RitualWatch
extends Node

## Watches what cancels a ritual: a doctor dies, the creature is lost, the site stops standing
## (unless the altar is already falling because its wizard died). It also starts that fall once the
## wizard is gone. What it does not do: drain, pay or end the ritual itself (it calls
## `ritual.abort()`). Ritual calls `step` once a tick, after Lift. Take this node out and nothing
## cancels it.

@export var ritual: Ritual


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Assign to `ritual` the Ritual it watches.")
	return warnings


func step() -> void:
	for doctor in ritual.doctors:
		if not is_instance_valid(doctor) or doctor.is_dead():
			ritual.abort()
			return
	var captive := ritual.captive
	if not is_instance_valid(ritual.creature) or captive == null or not captive.is_held():
		ritual.abort()
		return
	var drain := ritual.drain
	if (
		drain != null
		and ritual.type().collapses_target_altar
		and ritual.target_wizard != null
		and ritual.target_is_gone()
	):
		drain.collapse_altar()
	var falling := drain != null and drain.altar_falling
	if not falling and not ritual.site.is_standing():
		ritual.abort()
