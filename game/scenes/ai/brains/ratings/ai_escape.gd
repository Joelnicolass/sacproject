class_name AiEscape
extends RefCounted

## Teleport: when the wizard's threat is at least `escape_threat`, he jumps to the own building (altar, Manalith, shrine) farthest from
## him and beyond the reach his threat is measured in (senses.threat_far_m), so the jump takes him out of it. Worth: his own (what the
## side loses with him). Nothing while the threat is lower or with no such building. It does not cast (the support phase queues it on
## the building). Static. AI's own design (055f f5).


static func aim(caster: AiTrack, perception: AiPerception, tactics: AiTactics) -> AiTrack:
	if caster.threat < tactics.escape_threat:
		return null
	var best: AiTrack
	var best_d := tactics.senses.threat_far_m
	for site: AiTrack in perception.structures(0):
		if not site.is_valid() or site.site == AiTrack.Site.FOUNT or site.site == AiTrack.Site.NONE:
			continue
		var d := caster.cur_pos.distance_to(site.cur_pos)
		if d > best_d:
			best_d = d
			best = site
	return best


static func rate(caster: AiTrack, tactics: AiTactics) -> float:
	return caster.sort_key() if caster.threat >= tactics.escape_threat else 0.0
