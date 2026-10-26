class_name AiHealArea
extends RefCounted

## Rainbow, Healing Aura: what the health a heal on an area gives back around `target` (an own or ally body) is worth. Each own or
## ally body within the spell's reach (`effect_range_m`) of it that misses health, is not being summoned and has no heal running on
## it (a Rainbow or an aura still healing it, like AiHealRating.heal) counts its worth times
## the part of its health it misses; nothing when together they miss less than heal_area_min_missing. It reads the health the side
## knows (AiPerception.health_of). It does not cast (the support phase queues it). Static. AI's own design (055f f5).


static func rate(spell: SpellType, target: AiTrack, perception: AiPerception, tactics: AiTactics) -> float:
	if not target.is_body() or (target.relation != AiTrack.Relation.OWN and target.relation != AiTrack.Relation.ALLY):
		return 0.0
	var missing := 0
	var worth := 0.0
	for category in [0, 1]:
		for body: AiTrack in perception.bodies(category):
			if not AiWizardBrain.target_alive(body) or body.cur_pos.distance_to(target.cur_pos) > spell.effect_range_m:
				continue
			if body.node is UnitBody and (body.node as UnitBody).is_summoning():
				continue
			if body.node.get_node_or_null(HealEffect.NODE_NAME) != null:  # a heal already runs on it (AiHealRating.heal's rule)
				continue
			var hp := perception.health_of(body)
			if hp.y <= 0 or hp.x >= hp.y:
				continue
			missing += hp.y - hp.x
			worth += body.sort_key() * AiField.safediv(float(hp.y - hp.x), float(hp.y))
	return AiField.f32(worth) if float(missing) >= tactics.heal_area_min_missing else 0.0
