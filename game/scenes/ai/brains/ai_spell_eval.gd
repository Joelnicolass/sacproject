class_name AiSpellEval
extends RefCounted

## How the AI's wizard rates a spell on a target and picks the best of his book, from the
## SpellType's named fields only (`ai_use`, `ai_phase`, the «who it may land on» ticks, `ai_worth`);
## it does not cast nor look at tags. One evaluator per use (Rating), never per spell: AiSpellUses
## says which and on what body the cast lands.
## Ref: shiny.d:2799-2923 rateSpellAcc, 2925-2951 findBestSpell, 2930-2934

## The evaluator a spell is rated with (AiSpellUses.rate), from its `ai_use`.
enum Rating {
	NONE,
	SINGLE,
	AREA,
	HEAL,
	SPEEDUP,
	GUARD,
	DISABLE,
	SELF_AREA,
	TAKE_FOE,
	RAISE_DEAD,
	GATHER_SOULS,
	ESCAPE,
	GUARD_SITE,
	HEAL_AREA,
}

const RATING_OF_USE := {
	SpellType.AiUse.HIT_ONE: Rating.SINGLE,
	SpellType.AiUse.HIT_AREA: Rating.AREA,
	SpellType.AiUse.HEAL: Rating.HEAL,
	SpellType.AiUse.SPEEDUP: Rating.SPEEDUP,
	SpellType.AiUse.SELF_GUARD: Rating.GUARD,
	SpellType.AiUse.DISABLE_FOE: Rating.DISABLE,
	SpellType.AiUse.SELF_AREA: Rating.SELF_AREA,
	SpellType.AiUse.TAKE_FOE: Rating.TAKE_FOE,
	SpellType.AiUse.RAISE_DEAD: Rating.RAISE_DEAD,
	SpellType.AiUse.GATHER_SOULS: Rating.GATHER_SOULS,
	SpellType.AiUse.ESCAPE: Rating.ESCAPE,
	SpellType.AiUse.GUARD_SITE: Rating.GUARD_SITE,
	SpellType.AiUse.HEAL_AREA: Rating.HEAL_AREA,
}

var perception: AiPerception
var stance: AiStance
var groups: AiGroups
## The side's (AiPlay.tactics, given by AiWizardBrain.prepare).
var tactics: AiTactics


func _init(
	p_perception: AiPerception, p_stance: AiStance, p_groups: AiGroups, p_tactics: AiTactics
) -> void:
	perception = p_perception
	stance = p_stance
	groups = p_groups
	tactics = p_tactics


## The AI keeps in its book list the spells it may cast on its own: those with a phase (attack or
## support).
static func wants_acc(spell: SpellType) -> bool:
	return spell.ai_phase != SpellType.AiPhase.NEVER


## Which evaluator a spell uses, from its `ai_use` (the altar spells, Convert and Desecrate, have
## their own phases and no rating).
static func rating_of(spell: SpellType) -> Rating:
	return RATING_OF_USE.get(spell.ai_use, Rating.NONE)


## Whether the spell is cast in this phase (attack on a foe, support of an own body).
static func casts_in(spell: SpellType, phase: SpellType.AiPhase) -> bool:
	return phase != SpellType.AiPhase.NEVER and spell.ai_phase == phase


## Whether the kind of the target is one the spell lands on (none of the nine ticks: anything; a
## soul: the spells that tick «souls»).
static func lands_on(spell: SpellType, target: AiTrack) -> bool:
	if not (
		_names_a_kind(spell)
		or spell.only_free_manafounts
		or spell.only_allies
		or spell.never_allies
		or spell.targets_ground
	):
		return true
	match target.kind:
		AiTrack.Kind.WIZARD:
			return spell.targets_wizards
		AiTrack.Kind.CREATURE, AiTrack.Kind.MANAHOAR:
			return spell.targets_creatures
		AiTrack.Kind.STRUCTURE:
			return spell.targets_structures
		AiTrack.Kind.NONE:
			return spell.targets_souls and target.node is Soul
	return false


## Whether the spell may land on this target by side: no ally, a real structure, not a fount (a
## soul: its evaluator and the Caster judge).
func can_cast_on(_caster: AiTrack, target: AiTrack, spell: SpellType) -> bool:
	if not _names_a_kind(spell) or target.kind == AiTrack.Kind.NONE:
		return true
	var free_fount := (
		spell.only_free_manafounts
		and target.node is ManafountBody
		and (target.node as ManafountBody).is_free()
	)
	return side_allows(
		spell,
		free_fount,
		perception.relation_of(target.node),
		target.kind == AiTrack.Kind.STRUCTURE and target.node.is_in_group(ManafountBody.GROUP)
	)


## The side rule of can_cast_on: `only_free_manafounts`, `only_allies` (own or ally), then
## `never_allies` (neutral or enemy, and not a fount).
static func side_allows(
	spell: SpellType, free_fount: bool, relation: AiTrack.Relation, fount_structure: bool
) -> bool:
	if not _names_a_kind(spell):
		return true
	if spell.only_free_manafounts:
		return free_fount
	var friend := relation == AiTrack.Relation.OWN or relation == AiTrack.Relation.ALLY
	if spell.only_allies and not friend:
		return false
	if spell.never_allies:
		return not friend and not fount_structure
	return true


static func _names_a_kind(spell: SpellType) -> bool:
	return (
		spell.targets_wizards
		or spell.targets_souls
		or spell.targets_creatures
		or spell.targets_corpses
		or spell.targets_structures
	)


## What `spell` cast on `target` is worth. `looked_at`: the body the phase weighs when the cast
## lands elsewhere (a burst around him, a soul, a building); a spell «only on himself» counts when
## either is him. `dist_scaled`: findBestSpell's.
func rate(
	caster: AiTrack,
	spell: SpellType,
	target: AiTrack,
	dist_scaled: float,
	looked_at: AiTrack = null
) -> float:
	if not lands_on(spell, target):
		return 0.0
	if spell.ai_only_on_self and caster != target and caster != looked_at:
		return 0.0
	if not can_cast_on(caster, target, spell):
		return 0.0
	if dist_scaled > spell.cast_range_m * spell.cast_range_m:
		return 0.0
	return AiSpellUses.rate(self, rating_of(spell), caster, spell, target)


## F372: whether a queued Heal on `target` still rates over 0 with the health the side knows now
## (AiSpellUses.still_worth).
func still_worth(spell: Resource, target: AiTrack) -> bool:
	return AiSpellUses.still_worth(spell, target, perception, tactics)


## findBestSpell: the best spell against `target`, its cost paid out of the pool ((1 - cost/pool) *
## s). `target` in the answer is the body the best one lands on (AiSpellUses.aim: the target itself,
## him, a soul or a building).
func find_best(caster: AiTrack, target: AiTrack, phase: SpellType.AiPhase) -> Dictionary:
	var pool := float(AiRater.ftol(AiBody.mana_max(caster.node)) * stance.manalith_count())
	var dist_scaled := _dist_scaled(caster, target)
	var best := 0.0
	var best_spell: SpellType
	var best_aim: AiTrack
	for entry: Dictionary in caster.spell_accs:
		var spell: SpellType = entry["spell"]
		if not casts_in(spell, phase):
			continue
		var aim := AiSpellUses.aim(self, caster, spell, target)
		if aim == null:
			continue
		var s := rate(
			caster, spell, aim, dist_scaled if aim == target else _dist_scaled(caster, aim), target
		)
		s = AiField.spell_cost_scaled(s, spell.mana_cost, pool)
		if s > best:
			best = AiField.f32(s)
			best_spell = spell
			best_aim = aim
	if best_spell == null:
		return {"score": 0.0}
	return {
		"score": best,
		"spell": best_spell,
		"range": best_spell.cast_range_m,
		"obj": null,
		"target": best_aim
	}


## The squared distance findBestSpell rates by: distance² * range_distance_scale, 0 under
## near_distance_sq.
func _dist_scaled(caster: AiTrack, target: AiTrack) -> float:
	var dist_scaled := 0.0
	if target != null:
		var dse := caster.cur_pos.distance_squared_to(target.cur_pos) * tactics.range_distance_scale
		dist_scaled = dse
		if dse < tactics.near_distance_sq:
			dist_scaled = 0.0
	return dist_scaled
