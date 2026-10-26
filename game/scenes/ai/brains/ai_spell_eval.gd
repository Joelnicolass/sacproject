class_name AiSpellEval
extends RefCounted

## How the AI's wizard rates a spell on a target and picks the best of his book, from the SpellType's named fields only (`ai_use`,
## `ai_phase`, the «who it may land on» ticks, `ai_worth`); it does not cast nor look at tags. Evaluators (ratingFn): 0 none (rates 0),
## 1 single, 2 area (AiAreaRating), 3 heal and 4 speedup (AiHealRating), 5 guard (a ward on himself), 6 disable (a control spell on a foe).
## Ref: shiny.d:2799-2923 `rateSpellAcc`, 2925-2951 `findBestSpell`; RFC-024 §3.1.
const FN_NONE := 0
const FN_SINGLE := 1
const FN_AREA := 2
const FN_HEAL := 3
const FN_SPEEDUP := 4
const FN_GUARD := 5
const FN_DISABLE := 6
const FN_OF_USE := {SpellType.AiUse.HIT_ONE: FN_SINGLE, SpellType.AiUse.HIT_AREA: FN_AREA, SpellType.AiUse.HEAL: FN_HEAL,
	SpellType.AiUse.SPEEDUP: FN_SPEEDUP, SpellType.AiUse.SELF_GUARD: FN_GUARD, SpellType.AiUse.DISABLE_FOE: FN_DISABLE}

var perception: AiPerception
var stance: AiStance
var groups: AiGroups
var tactics: AiTactics  # the side's (AiPlay.tactics, given by AiWizardBrain.prepare)


func _init(p_perception: AiPerception, p_stance: AiStance, p_groups: AiGroups, p_tactics: AiTactics) -> void:
	perception = p_perception
	stance = p_stance
	groups = p_groups
	tactics = p_tactics


## The AI keeps in its book list the spells it may cast on its own: those with a phase (attack or support).
static func wants_acc(spell: SpellType) -> bool:
	return spell.ai_phase != SpellType.AiPhase.NEVER


## Which evaluator a spell uses, from its `ai_use` (the altar spells, Convert and Desecrate, have their own phases and no rating).
static func rating_fn(spell: SpellType) -> int:
	return int(FN_OF_USE.get(spell.ai_use, FN_NONE))


## Whether the spell is cast in this phase (attack on a foe, support of an own body).
static func casts_in(spell: SpellType, phase: SpellType.AiPhase) -> bool:
	return phase != SpellType.AiPhase.NEVER and spell.ai_phase == phase


## Whether the kind of the target is one the spell lands on (a spell with none of the nine ticks lands on anything).
static func lands_on(spell: SpellType, target: AiTrack) -> bool:
	if not (_names_a_kind(spell) or spell.only_free_manafounts or spell.only_allies or spell.never_allies or spell.targets_ground):
		return true
	match target.kind:
		AiTrack.Kind.WIZARD:
			return spell.targets_wizards
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR:
			return spell.targets_creatures
		AiTrack.Kind.STRUCTURE:
			return spell.targets_structures
	return false


## Whether the spell may land on this target by side: no ally, a real structure, not a fount.
func can_cast_on(_caster: AiTrack, target: AiTrack, spell: SpellType) -> bool:
	if not _names_a_kind(spell):
		return true
	var free_fount := spell.only_free_manafounts and target.node is ManafountBody and (target.node as ManafountBody).is_free()
	return side_allows(spell, free_fount, perception.relation_of(target.node),
		target.kind == AiTrack.Kind.STRUCTURE and target.node.is_in_group(&"manafount"))


## The side rule of can_cast_on (relation: 0 own, 1 ally, 2-3 not): `only_free_manafounts`, `only_allies`, then `never_allies`.
static func side_allows(spell: SpellType, free_fount: bool, relation: int, fount_structure: bool) -> bool:
	if not _names_a_kind(spell):
		return true
	if spell.only_free_manafounts:
		return free_fount
	if spell.only_allies and relation > 1:
		return false
	if spell.never_allies:
		return relation > 1 and not fount_structure
	return true


static func _names_a_kind(spell: SpellType) -> bool:
	return spell.targets_wizards or spell.targets_souls or spell.targets_creatures or spell.targets_corpses or spell.targets_structures


## rateSpellAcc (shiny.d:2799-2923) for the evaluators of 024c. `dist_scaled` is findBestSpell's (shiny.d:2930-2934).
func rate(caster: AiTrack, spell: SpellType, target: AiTrack, dist_scaled: float) -> float:
	if not lands_on(spell, target):
		return 0.0
	if spell.ai_only_on_self and caster != target:
		return 0.0
	if not can_cast_on(caster, target, spell):
		return 0.0
	if dist_scaled > spell.cast_range_m * spell.cast_range_m:
		return 0.0
	match rating_fn(spell):
		FN_SINGLE:
			return _single(spell, target)
		FN_AREA:
			return AiAreaRating.rate(spell, target, target.cur_pos, groups)
		FN_HEAL:
			return AiHealRating.heal(spell, target, perception, tactics)
		FN_SPEEDUP:
			return AiHealRating.speedup(target)
		FN_GUARD:
			return AiGuard.rate(spell, target, perception, tactics)
		FN_DISABLE:
			return AiDisable.rate(spell, caster, target, tactics)
	return 0.0


## f489780 (shiny.d:2830-2842): worth of an enemy target (a wizard, a creature or a structure) x the part of its health the spell takes.
func _single(spell: SpellType, target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.relation != AiTrack.Relation.ENEMY:
		return 0.0
	var hp := perception.health_of(target)
	var m := mini(spell.ai_worth, hp.x)
	var ratio := AiField.f32(AiField.safediv(float(m), float(hp.y)))
	return AiField.f32(target.sort_key() * ratio)


## F372: whether a queued Heal on `target` still rates over 0 with the health the side knows now (AiHealRating.still_worth).
func still_worth(spell: Resource, target: AiTrack) -> bool:
	return AiHealRating.still_worth(spell, target, perception, tactics)


## findBestSpell (shiny.d:2925-2951): the best spell against `target`, its cost paid out of the pool ((1 - cost/pool) * s).
func find_best(caster: AiTrack, target: AiTrack, phase: SpellType.AiPhase) -> Dictionary:
	var pool := float(AiRater.ftol(AiBody.mana_max(caster.node)) * stance.manalith_count())
	var dist_scaled := 0.0
	if target != null:
		var dse := caster.cur_pos.distance_squared_to(target.cur_pos) * tactics.range_distance_scale
		dist_scaled = dse
		if dse < tactics.near_distance_sq:
			dist_scaled = 0.0
	var best := 0.0
	var best_spell: SpellType
	for entry: Dictionary in caster.spell_accs:
		var spell: SpellType = entry["spell"]
		if not casts_in(spell, phase):
			continue
		var s := rate(caster, spell, target, dist_scaled)
		s = AiField.spell_cost_scaled(s, spell.mana_cost, pool)
		if s > best:
			best = AiField.f32(s)
			best_spell = spell
	if best_spell == null:
		return {"score": 0.0}
	return {"score": best, "spell": best_spell, "range": best_spell.cast_range_m, "obj": null}
