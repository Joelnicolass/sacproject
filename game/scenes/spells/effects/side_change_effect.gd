@tool
class_name SideChangeEffect
extends BodyEffect

## Charm's change: the creature is, from now on and for good, of the wizard's side. It forgets its orders and its target, is told to follow the
## wizard (`retreat`) and bursts into hearts. It refuses a wizard, a creature of the same side and one that is not alive; it does not ask whether
## the creature may be charmed in the first place (the spell's SpellTarget does) and it does not give it back.
## Ref: sacengine charm (state.d:21915-21950): clearOrderQueue, side = wizard's, order retreat to the wizard, 128 bouncingHeart, CharmHeart.

## The hearts that burst from the creature (a ParticleType under data/fx/, with its light).
@export var hearts: ParticleType


func apply(carrier: SpellCarrier, body: Node3D) -> bool:
	var unit := body as UnitBody
	var wizard := carrier.wizard()
	if unit == null or wizard == null or not is_live(body) or body.is_in_group(WizardBody.GROUP) or unit.owner_slot == carrier.from_slot:
		return false
	unit.owner_slot = carrier.from_slot
	unit.engagement.follow(wizard)
	if hearts != null:
		FxBus.broadcast(hearts, BodyNudge.center(unit))
	return true
