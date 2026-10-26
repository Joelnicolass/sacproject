class_name AiGuardSite
extends RefCounted

## Guardian: an own creature tied to a building of his side that enemies press (at least guard_min_foes known foes within
## guard_threat_m of it, the numbers of his ward), while the creature is free to be tied (GuardianAction.can_guard). Worth: the
## creature's, 1 within guard_threat_m of that building and falling to 0 at senses.threat_far_m. Whether he stands near enough a
## building to cast it is the Caster's answer (Casting asks it). It does not cast. Static. AI's own design (055f f5).


static func rate(target: AiTrack, perception: AiPerception, tactics: AiTactics) -> float:
	if target.kind != AiTrack.Kind.CREATURE or target.relation != AiTrack.Relation.OWN or not target.is_valid():
		return 0.0
	if not GuardianAction.can_guard(perception.slot, target.node):
		return 0.0
	var best := 0.0
	for site: AiTrack in perception.structures(0):
		if not site.is_valid() or site.site == AiTrack.Site.FOUNT or not pressed(site, perception.bodies(3), tactics):
			continue
		best = maxf(best, AiField.ramp(target.cur_pos.distance_to(site.cur_pos), tactics.guard_threat_m, tactics.senses.threat_far_m))
	return AiField.f32(target.sort_key() * best)


## At least guard_min_foes of `foes` stand within guard_threat_m of `site` (where the side believes they are).
static func pressed(site: AiTrack, foes: Array, tactics: AiTactics) -> bool:
	var count := 0
	for foe: AiTrack in foes:
		if AiWizardBrain.target_alive(foe) and foe.cur_pos.distance_to(site.cur_pos) <= tactics.guard_threat_m:
			count += 1
	return count >= tactics.guard_min_foes
