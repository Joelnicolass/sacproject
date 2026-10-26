class_name AiRaiseDead
extends RefCounted

## Animate Dead: which soul the wizard may raise (one his side may fetch that still lies on its dead creature, within the spell's
## range of him) and what that creature is worth, the same worth it has to summon. Nothing without such a soul. It does not cast
## (the support phase queues it on the soul). Static. AI's own design (055f f5).


## The raisable soul within range of the wizard whose creature is worth most, as a track (AiSouls.soul_track), or null.
static func aim(caster: AiTrack, spell: SpellType, perception: AiPerception) -> AiTrack:
	var best: Soul
	var best_worth := 0.0
	for node in perception.get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if not raisable(soul, perception.slot) or caster.cur_pos.distance_to(soul.global_position) > spell.cast_range_m:
			continue
		var worth := worth_of(soul)
		if worth > best_worth:
			best_worth = worth
			best = soul
	return perception.souls.soul_track(best) if best != null and perception.souls != null else null


static func rate(target: AiTrack, slot: int) -> float:
	var soul: Soul = target.node as Soul if target.is_valid() else null
	return worth_of(soul) if raisable(soul, slot) else 0.0


## A soul `slot` may fetch that still holds its dead creature (the rule of AnimateDeadAction.check).
static func raisable(soul: Soul, slot: int) -> bool:
	if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion() or not soul.fetchable_by(slot):
		return false
	var corpse := soul.corpse as UnitBody
	return corpse != null and is_instance_valid(corpse) and corpse.is_dead()


## What the dead creature of `soul` is worth (AiTrackFacts.tag_acc, the rating of its type).
static func worth_of(soul: Soul) -> float:
	var corpse: UnitBody = soul.corpse as UnitBody if soul != null else null
	if corpse == null or not is_instance_valid(corpse) or corpse.type == null:
		return 0.0
	return AiRater.rate(AiTrackFacts.tag_acc(corpse.type))
