@tool
class_name AfflictEffect
extends BodyEffect

## Lays a state on the body with the carrier's spell: the body's Afflictions child of `affliction` takes it for the spell's duration (Blind Rage's
## fury). It does not say how long it lasts nor what it does (the state does), and it refuses a body that has no such state.

@export var affliction: AfflictionType


func apply(carrier: SpellCarrier, body: Node3D) -> bool:
	if affliction == null or not is_live(body):
		return false
	var owner_node := Afflictions.of(body)
	var state := owner_node.child_for(affliction) if owner_node != null else null
	return state != null and state.lay(carrier.spell, carrier.from_slot)
