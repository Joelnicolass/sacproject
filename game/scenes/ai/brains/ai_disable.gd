class_name AiDisable
extends RefCounted

## What a control spell on a foe is worth to the AI's wizard (Freeze, Grasping Vines, Rings of Fire, Slime): the foe's own rating times
## the share of `disable_ref_s` the state would last on it. A body the spell may not land on (an ally, a structure, a flier for the Vines,
## one already protected from crowd control) is worth nothing. The original has no such evaluator (its flags give 0); this is the AI's
## common sense (RFC-053 §7). It never casts: AiSpellEval calls it and the attack phase queues the result.


static func rate(spell: SpellType, caster: AiTrack, target: AiTrack, tactics: AiTactics) -> float:
	var wizard := caster.node as WizardBody
	var casting := Caster.of(wizard)
	var action := casting.action_for(spell.tag) as AfflictAction if casting != null else null
	if action == null or action.target == null or target.node == null or target.relation != AiTrack.Relation.ENEMY:
		return 0.0
	var body := action.target.pick(wizard, target.node as Node3D)
	if body == null:
		return 0.0
	var seconds := action.expected_seconds(spell, body)
	return target.sort_key() * minf(1.0, seconds / tactics.disable_ref_s)
