class_name AiGuard
extends RefCounted

## What a ward on himself is worth to the AI's wizard (Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm): his own
## rating while at least `guard_min_foes` known enemies stand within `guard_threat_m` of him and the ward is off, else nothing.
## The original has no such evaluator (its flags give 0); this is the AI's common sense (RFC-053 §7). It never casts: AiSpellEval
## calls it and the support phase queues the result.


static func rate(spell: SpellType, caster: AiTrack, perception: AiPerception, tactics: AiTactics) -> float:
	var wards := Wards.of(caster.node)
	var ward := wards.ward_for(spell) if wards else null
	if ward == null or ward.is_on():
		return 0.0
	var foes := 0
	for foe: AiTrack in perception.bodies(3):
		if AiWizardBrain.target_alive(foe) and caster.cur_pos.distance_to(foe.cur_pos) <= tactics.guard_threat_m:
			foes += 1
	return caster.sort_key() if foes >= tactics.guard_min_foes else 0.0
