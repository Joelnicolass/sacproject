@tool
class_name GibEffect
extends BodyEffect

## The creature bursts into blood and its soul stays on the ground (Gib). Intestinal Vaporization
## does it when the swelling ends and Bovine Intervention when the cow lands on its target. It does
## not decide when (the carrier's signal) and it leaves no corpse.

## A flash and a sound at the place it burst (a ParticleType under scenes/fx/effects/, with its
## light).
## Optional.
@export var flash: ParticleType


func apply(carrier: SpellCarrier, body: Node3D) -> bool:
	if not is_live(body) or not body is UnitBody:
		return false
	var center := (body as UnitBody).soul_anchor()
	var burst := Gib.burst(body as UnitBody, carrier.from_slot)
	if burst and flash != null:
		FxBus.broadcast(flash, center)
	return burst
