class_name AiGatherSouls
extends RefCounted

## Soul Wind, Soul Mole: the soul the wizard sends for instead of walking to it. It is the nearest one his side may fetch, that no
## spell carries yet, farther than a short walk (soul_send_min_m, or the reach he takes souls by touching now when that is shorter:
## (1 - threat) * soul_reach_scale + soul_reach_base, the brain's) and inside the spell's range. Worth: his own (a soul is one more
## creature for his side, like the ward's worth), plus, for a spell that hurts on its way (`ai_worth`, Soul Wind), the part of their health it takes from the known foes within `effect_range_m` of the soul.
## It does not cast (the support phase queues it on the soul). Static. AI's own design (055f f5).


## The soul to send for, as a track (AiSouls.soul_track), or null.
static func aim(caster: AiTrack, spell: SpellType, perception: AiPerception, tactics: AiTactics) -> AiTrack:
	var reach := touch_reach(caster, tactics)
	var best: Soul
	var best_d := INF
	for node in perception.get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion() or not soul.fetchable_by(perception.slot):
			continue
		if soul.carrier != null and is_instance_valid(soul.carrier):
			continue
		var d := caster.cur_pos.distance_to(soul.global_position)
		if fits(d, minf(reach, tactics.soul_send_min_m), spell.cast_range_m) and d < best_d:
			best_d = d
			best = soul
	return perception.souls.soul_track(best) if best != null and perception.souls != null else null


## How far the wizard walks to a soul now (AiWizardBrain.think).
static func touch_reach(caster: AiTrack, tactics: AiTactics) -> float:
	return AiField.f32((1.0 - caster.threat) * tactics.soul_reach_scale + tactics.soul_reach_base)


## A soul at `distance_m` is one to send for: farther than he would walk for it (`reach_m`) and the spell reaches it.
static func fits(distance_m: float, reach_m: float, range_m: float) -> bool:
	return distance_m > reach_m and distance_m <= range_m


static func rate(spell: SpellType, caster: AiTrack, target: AiTrack, perception: AiPerception) -> float:
	var soul: Soul = target.node as Soul if target.is_valid() else null
	if soul == null or not soul.fetchable_by(perception.slot):
		return 0.0
	var worth := caster.sort_key()
	if spell.ai_worth > 0:
		for foe: AiTrack in perception.bodies(3):
			if not AiWizardBrain.target_alive(foe) or foe.cur_pos.distance_to(soul.global_position) > spell.effect_range_m:
				continue
			var hp := perception.health_of(foe)
			worth += foe.sort_key() * minf(1.0, AiField.safediv(float(spell.ai_worth), float(hp.y)))
	return AiField.f32(worth)
