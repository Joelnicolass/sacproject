@tool
class_name BodyEffect
extends Resource

## What a spell does to ONE body when its SpellCarrier gets there: the base does nothing. A TargetEffect child of the carrier embeds one of its
## subclasses (AfflictEffect, GibEffect, KillEffect, SideChangeEffect) and calls it for the target, or for each body in its reach. A new thing a
## carrier can do is a new subclass and a scene, never a branch on the spell. Server (or solo) only.


## True when the body was affected. `carrier` gives the spell (`spell`), the side that cast it (`from_slot`) and the wizard (`wizard()`).
func apply(_carrier: SpellCarrier, _body: Node3D) -> bool:
	return false


## The body is still in the match and alive (the effect may land on it).
static func is_live(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var health := Health.of(body)
	return health != null and not health.is_dead()
