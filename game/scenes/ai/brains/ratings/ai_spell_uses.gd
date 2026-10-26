class_name AiSpellUses
extends RefCounted

## For each use a spell has for the AI (SpellType.ai_use), the evaluator that rates it and the body the cast lands on: the target
## the phase weighs, or for the uses that aim elsewhere the wizard himself (a burst around him), a soul (raise, gather) or an own
## building (escape). A new spell with an existing use needs no code: its `ai_use` and `ai_phase`. It does not cast nor pick the
## best spell (AiSpellEval.find_best). Static.


## What a cast of `spell` (its evaluator `fn`) on `target` is worth, with the side's knowledge (`eval.perception`) and tactics.
static func rate(eval: AiSpellEval, fn: int, caster: AiTrack, spell: SpellType, target: AiTrack) -> float:
	var perception := eval.perception
	var tactics := eval.tactics
	match fn:
		AiSpellEval.FN_SINGLE:
			return single(perception, spell, target)
		AiSpellEval.FN_AREA:
			return AiAreaRating.rate(spell, target, target.cur_pos, eval.groups)
		AiSpellEval.FN_HEAL:
			return AiHealRating.heal(spell, target, perception, tactics)
		AiSpellEval.FN_SPEEDUP:
			return AiHealRating.speedup(target)
		AiSpellEval.FN_GUARD:
			return AiGuard.rate(spell, target, perception, tactics)
		AiSpellEval.FN_DISABLE:
			return AiDisable.rate(spell, caster, target, tactics)
		AiSpellEval.FN_SELF_AREA:
			return AiSelfArea.rate(spell, caster, perception.bodies(3), tactics)
		AiSpellEval.FN_TAKE_FOE:
			return AiTakeFoe.rate(spell, caster, target)
		AiSpellEval.FN_RAISE_DEAD:
			return AiRaiseDead.rate(target, perception.slot)
		AiSpellEval.FN_GATHER_SOULS:
			return AiGatherSouls.rate(spell, caster, target, perception)
		AiSpellEval.FN_ESCAPE:
			return AiEscape.rate(caster, tactics)
		AiSpellEval.FN_GUARD_SITE:
			return AiGuardSite.rate(target, perception, tactics)
		AiSpellEval.FN_HEAL_AREA:
			return AiHealArea.rate(spell, target, perception, tactics)
	return 0.0


## The body a cast of `spell` lands on while the phase weighs `target`, or null when there is none. The uses that look from where he
## stands (raise, gather, escape) answer only while the phase weighs the wizard himself, so the support phase counts them once.
static func aim(eval: AiSpellEval, caster: AiTrack, spell: SpellType, target: AiTrack) -> AiTrack:
	match AiSpellEval.rating_fn(spell):
		AiSpellEval.FN_SELF_AREA:
			return caster
		AiSpellEval.FN_RAISE_DEAD:
			return AiRaiseDead.aim(caster, spell, eval.perception) if target == caster else null
		AiSpellEval.FN_GATHER_SOULS:
			return AiGatherSouls.aim(caster, spell, eval.perception, eval.tactics) if target == caster else null
		AiSpellEval.FN_ESCAPE:
			return AiEscape.aim(caster, eval.perception, eval.tactics) if target == caster else null
	return target


## A spell on one enemy body (a wizard, a creature or a structure): its worth times the part of its health the spell takes
## (`ai_worth` against the health the side knows). Ref: shiny.d:2830-2842 f489780.
static func single(perception: AiPerception, spell: SpellType, target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.relation != AiTrack.Relation.ENEMY:
		return 0.0
	var hp := perception.health_of(target)
	var m := mini(spell.ai_worth, hp.x)
	var ratio := AiField.f32(AiField.safediv(float(m), float(hp.y)))
	return AiField.f32(target.sort_key() * ratio)
