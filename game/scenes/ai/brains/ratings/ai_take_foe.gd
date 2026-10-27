class_name AiTakeFoe
extends RefCounted

## What taking an enemy creature for his side is worth (Charm): the creature's own worth. A wizard, a structure, a soul, an own or
## ally body are worth nothing, and so is a creature of no player when the spell's target rule refuses those
## (SpellTarget.neutral_allowed). The Caster still has the last word (Casting asks it). Static. AI's own design (055f f5).


static func rate(spell: SpellType, caster: AiTrack, target: AiTrack) -> float:
	if target.kind != AiTrack.Kind.CREATURE and target.kind != AiTrack.Kind.MANAHOAR:
		return 0.0
	if target.relation == AiTrack.Relation.OWN or target.relation == AiTrack.Relation.ALLY:
		return 0.0
	var unit: UnitBody = target.node as UnitBody if target.is_valid() else null
	if unit != null and unit.owner_slot <= 0 and not takes_neutral(spell, caster):
		return 0.0
	return target.sort_key()


## Whether the spell's own target rule takes a creature of no player (no rule known: yes, the Caster decides).
static func takes_neutral(spell: SpellType, caster: AiTrack) -> bool:
	var casting: Caster = Caster.of(caster.node) if caster.is_valid() else null
	var action: CarrierAction = casting.action_for(spell.tag) as CarrierAction if casting != null else null
	return action == null or action.target == null or action.target.neutral_allowed
