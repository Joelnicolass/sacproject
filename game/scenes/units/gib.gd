class_name Gib
extends RefCounted

## A creature bursts into blood: no corpse is left, the body is gone the next tick and its soul stays on the ground (SoulSystem puts it
## there because the body is `gibbed`). It dies like any other death (`Health.died`, the match counts it); what is different is what stays.
## It does not choose who bursts (the spell does) and a creature that falls into a hole bursts the same way but leaves no soul (`fall_into_hole`).

## The bursts: the cloud and the spray (the same as a creature that falls into a hole), at the body's center (`soul_anchor`, the
## CENTER socket of the body as it lies).
const CLOUD: ParticleType = preload("res://data/fx/hover_blood.tres")
const SPRAY: ParticleType = preload("res://data/fx/blood.tres")


## Server or solo. True when `body` burst; false when it is gone, dead already or has nothing to kill.
static func burst(body: UnitBody, from_slot := 0) -> bool:
	if (
		body == null
		or not is_instance_valid(body)
		or not body.is_inside_tree()
		or body.is_dead()
		or not body.simulates()
	):
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


## A creature far below the land over a hole bursts with no soul and is gone at once (Locomotion.fell). Frees the body in the middle of its step.
static func fall_into_hole(body: UnitBody) -> void:
	body.set_physics_process(false)
	var center := body.soul_anchor()
	FxBus.broadcast(CLOUD, center)
	FxBus.broadcast(SPRAY, center)
	print("%s falls into the void" % body.display_name())
	body.queue_free()
