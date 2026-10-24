class_name Gib
extends RefCounted

## A creature bursts into blood: no corpse is left, the body is gone the next tick and its soul stays on the ground (SoulSystem puts it
## there because the body is `gibbed`). It dies like any other death (`Health.died`, the match counts it); what is different is what stays.
## It does not choose who bursts (the spell does) and it does not fall to a hole (`UnitBody._gib_fallen`, which leaves no soul).
## Ref: sacengine gib (state.d:8310-8364), the blood of gibAnimation.

## FxBus names of the burst: the cloud and the spray (the same as a creature that falls into a hole).
const CLOUD := "hover_blood"
const SPRAY := "blood"


## Server or solo. True when `body` burst; false when it is gone, dead already or has nothing to kill.
static func burst(body: UnitBody, from_slot := 0) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree() or body.is_dead() or not body.simulates():
		return false
	var health := Health.of(body)
	if health == null or health.maximum <= 0.0:
		return false
	var center := body.soul_anchor()
	body.gibbed = true
	body.visible = false
	body.died.connect(body.queue_free.unbind(3), CONNECT_ONE_SHOT)
	FxBus.broadcast(CLOUD, center)
	FxBus.broadcast(SPRAY, center)
	health.kill(from_slot)
	return true
