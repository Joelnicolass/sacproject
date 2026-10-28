class_name AiSpellUses
extends RefCounted

## For each use a spell has for the AI (SpellType.ai_use, AiSpellEval.Rating), the evaluator that
## rates it and the body the cast lands on: the target the phase weighs, or for the uses that aim
## elsewhere the wizard himself (a burst around him), a soul (raise, gather) or an own building
## (escape). A new spell with an existing use needs no code: its `ai_use` and `ai_phase`. It does
## not cast nor pick the best spell (AiSpellEval.find_best). Static.
## The uses marked «AI's own design» have no evaluator in the original (its flags give 0): they are
## the AI's common sense.

const UnitOrders := preload("res://scenes/units/unit_orders.gd")
## Speedup: the base distance of an advancing creature, of a body going to a soul (or guarding or
## moving), and the distance to its goal under which it is worth nothing.
const SPEEDUP_ADVANCE_BASE_M := 60.0
const SPEEDUP_WALK_BASE_M := 40.0
const SPEEDUP_MIN_SQ := 100.0


## What a cast of `spell` (its evaluator `rating`) on `target` is worth, with the side's knowledge
## (`eval.perception`) and tactics.
static func rate(
	eval: AiSpellEval,
	rating: AiSpellEval.Rating,
	caster: AiTrack,
	spell: SpellType,
	target: AiTrack
) -> float:
	var perception := eval.perception
	var tactics := eval.tactics
	match rating:
		AiSpellEval.Rating.SINGLE:
			return single(perception, spell, target)
		AiSpellEval.Rating.AREA:
			return AiAreaRating.rate(spell, target, target.cur_pos, eval.groups)
		AiSpellEval.Rating.HEAL:
			return heal(spell, target, perception, tactics)
		AiSpellEval.Rating.SPEEDUP:
			return speedup(target)
		AiSpellEval.Rating.GUARD:
			return ward(spell, target, perception, tactics)
		AiSpellEval.Rating.DISABLE:
			return disable(spell, caster, target, tactics)
		AiSpellEval.Rating.SELF_AREA:
			return self_area(spell, caster, perception.bodies(AiTrack.Relation.ENEMY), tactics)
		AiSpellEval.Rating.TAKE_FOE:
			return take_foe(spell, caster, target)
		AiSpellEval.Rating.RAISE_DEAD:
			return raise_dead(target, perception.slot)
		AiSpellEval.Rating.GATHER_SOULS:
			return gather_souls(spell, caster, target, perception)
		AiSpellEval.Rating.ESCAPE:
			return escape(caster, tactics)
		AiSpellEval.Rating.GUARD_SITE:
			return guard_site(target, perception, tactics)
		AiSpellEval.Rating.HEAL_AREA:
			return heal_area(spell, target, perception, tactics)
	return 0.0


## The body a cast of `spell` lands on while the phase weighs `target`, or null when there is none.
## The uses that look from where he stands (raise, gather, escape) answer only while the phase
## weighs the wizard himself, so the support phase counts them once.
static func aim(eval: AiSpellEval, caster: AiTrack, spell: SpellType, target: AiTrack) -> AiTrack:
	match AiSpellEval.rating_of(spell):
		AiSpellEval.Rating.SELF_AREA:
			return caster
		AiSpellEval.Rating.RAISE_DEAD:
			return raise_dead_aim(caster, spell, eval.perception) if target == caster else null
		AiSpellEval.Rating.GATHER_SOULS:
			if target != caster:
				return null
			return gather_souls_aim(caster, spell, eval.perception, eval.tactics)
		AiSpellEval.Rating.ESCAPE:
			return escape_aim(caster, eval.perception, eval.tactics) if target == caster else null
	return target


## A spell on one enemy body (a wizard, a creature or a structure): its worth times the part of its
## health the spell takes (`ai_worth` against the health the side knows).
static func single(perception: AiPerception, spell: SpellType, target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.relation != AiTrack.Relation.ENEMY:
		return 0.0
	var hp := perception.health_of(target)
	var m := mini(spell.ai_worth, hp.x)
	var ratio := AiField.f32(AiField.safediv(float(m), float(hp.y)))
	return AiField.f32(target.sort_key() * ratio)


## Heal: worth of the target x the part of its health the spell would give back. Not on an enemy and
## not on one with a heal running. Nor on a body at or over `heal_below_ratio` of
## its health, nor on one that misses less than `heal_min_missing`, nor on one still being summoned
## (the original heals whatever is not full).
static func heal(
	spell: SpellType, target: AiTrack, perception: AiPerception, tactics: AiTactics
) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STRUCTURE:
		return 0.0
	if target.relation == AiTrack.Relation.ENEMY:
		return 0.0
	if target.node.get_node_or_null(HealEffect.NODE_NAME) != null:
		return 0.0
	if target.node is UnitBody and (target.node as UnitBody).is_summoning():
		return 0.0
	var hp := perception.health_of(target)
	if hp.y == 0:
		return 0.0
	var missing := hp.y - hp.x
	if float(hp.x) >= tactics.heal_below_ratio * float(hp.y):
		return 0.0
	if float(missing) < tactics.heal_min_missing:
		return 0.0
	var healed := mini(spell.damage, missing)
	return AiField.f32(target.sort_key() * AiField.safediv(float(healed), float(hp.y)))


## Whether a queued Heal on `target` still rates over 0 with the health the side knows now (the
## queue can be 16 ticks old). Any other spell answers true.
static func still_worth(
	spell: Resource, target: AiTrack, perception: AiPerception, tactics: AiTactics
) -> bool:
	if not (spell is SpellType) or target == null:
		return true
	if AiSpellEval.rating_of(spell as SpellType) != AiSpellEval.Rating.HEAL:
		return true
	return heal(spell as SpellType, target, perception, tactics) > 0.0


## Speedup: worth of the target x (its distance to where its order goes)² / base². A creature that
## is advancing (a wizard is left out, and so is one with spells of its own) weighs
## SPEEDUP_ADVANCE_BASE_M; one that goes to a soul or guards or moves (AiOrder.TAKE_SOUL, the
## original's ostate 0x22) weighs SPEEDUP_WALK_BASE_M. Nearer than 10 m to the goal: nothing. A
## creature that already runs faster (a Speedup on it) is the spell's own exclusion: the Caster
## would answer «Blanco inválido», so it rates 0.
static func speedup(target: AiTrack) -> float:
	if target.kind == AiTrack.Kind.NONE or target.kind == AiTrack.Kind.STRUCTURE:
		return 0.0
	if target.node.get_node_or_null("SpeedupEffect") != null:
		return 0.0
	var base := 0.0
	var goal := Vector3.ZERO
	if target.kind == AiTrack.Kind.WIZARD:
		if target.ord_state != AiCommandPort.AiOrder.TAKE_SOUL:
			return 0.0
		if not (target.node as WizardBody).is_walking():
			return 0.0
		base = SPEEDUP_WALK_BASE_M
		goal = target.ord_pos
	else:
		var orders := target.node.get_node_or_null("Orders")
		if orders == null:
			return 0.0
		var command := int(orders.get("command"))
		var aim_node: Variant = orders.get("target")
		var point := orders.get("point") as Vector3
		if aim_node != null and is_instance_valid(aim_node):
			point = (aim_node as Node3D).global_position
		var advancing := command == UnitOrders.Command.ADVANCE
		var walking := (
			command == UnitOrders.Command.GUARD
			or command == UnitOrders.Command.GUARD_AREA
			or command == UnitOrders.Command.MOVE
		)
		if target.ord_state == AiCommandPort.AiOrder.ADVANCE and advancing:
			var type: Variant = target.node.get("type")
			if type != null and AiTrackFacts.ability_count(type as CreatureType) > 0:
				return 0.0
			base = SPEEDUP_ADVANCE_BASE_M
		elif target.ord_state == AiCommandPort.AiOrder.TAKE_SOUL and walking:
			base = SPEEDUP_WALK_BASE_M
		else:
			return 0.0
		goal = point
	var d2 := AiField.f32(target.cur_pos.distance_squared_to(goal))
	if d2 < SPEEDUP_MIN_SQ:
		return 0.0
	return AiField.f32(target.sort_key() * AiField.safediv(d2, base * base))


## A ward on himself (Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm): his own
## rating while at least `guard_min_foes` known enemies stand within `guard_threat_m` of him and the
## ward is off, else nothing. AI's own design.
static func ward(
	spell: SpellType, caster: AiTrack, perception: AiPerception, tactics: AiTactics
) -> float:
	var wards := Wards.of(caster.node)
	var on := wards.ward_for(spell) if wards else null
	if on == null or on.is_on():
		return 0.0
	var foes := 0
	for foe: AiTrack in perception.bodies(AiTrack.Relation.ENEMY):
		if not AiWizardBrain.target_alive(foe):
			continue
		if caster.cur_pos.distance_to(foe.cur_pos) <= tactics.guard_threat_m:
			foes += 1
	return caster.sort_key() if foes >= tactics.guard_min_foes else 0.0


## A control spell on a foe (Freeze, Grasping Vines, Rings of Fire, Slime): the foe's own rating
## times the share of `disable_ref_s` the state would last on it. A body the spell may not land on
## (an ally, a structure, a flier for the Vines, one already protected from crowd control) is worth
## nothing. AI's own design.
static func disable(
	spell: SpellType, caster: AiTrack, target: AiTrack, tactics: AiTactics
) -> float:
	var wizard := caster.node as WizardBody
	var casting := Caster.of(wizard)
	var action := casting.action_for(spell.tag) as AfflictAction if casting != null else null
	if action == null or action.target == null or target.node == null:
		return 0.0
	if target.relation != AiTrack.Relation.ENEMY:
		return 0.0
	var body := action.target.pick(wizard, target.node as Node3D)
	if body == null:
		return 0.0
	var seconds := action.expected_seconds(spell, body)
	return target.sort_key() * minf(1.0, seconds / tactics.disable_ref_s)


## A burst around the wizard himself (Halo of Earth): what the known enemy bodies inside the
## spell's reach (`effect_range_m`) of him are worth together, once they are at least
## `self_area_min_foes`; nothing with fewer. It reads where the side believes they are
## (AiTrack.cur_pos). AI's own design.
static func self_area(spell: SpellType, caster: AiTrack, foes: Array, tactics: AiTactics) -> float:
	var count := 0
	var worth := 0.0
	for foe: AiTrack in foes:
		if not foe.is_body() or not AiWizardBrain.target_alive(foe):
			continue
		if caster.cur_pos.distance_to(foe.cur_pos) <= spell.effect_range_m:
			count += 1
			worth += foe.sort_key()
	return AiField.f32(worth) if count >= tactics.self_area_min_foes else 0.0


## Taking an enemy creature for his side (Charm): the creature's own worth. A wizard, a structure,
## a soul, an own or ally body are worth nothing, and so is a creature of no player when the spell's
## target rule refuses those (SpellTarget.neutral_allowed). The Caster still has the last word
## (Casting asks it). AI's own design.
static func take_foe(spell: SpellType, caster: AiTrack, target: AiTrack) -> float:
	if target.kind != AiTrack.Kind.CREATURE and target.kind != AiTrack.Kind.MANAHOAR:
		return 0.0
	if target.relation == AiTrack.Relation.OWN or target.relation == AiTrack.Relation.ALLY:
		return 0.0
	var unit: UnitBody = target.node as UnitBody if target.is_valid() else null
	if unit != null and unit.owner_slot <= 0 and not _takes_neutral(spell, caster):
		return 0.0
	return target.sort_key()


## Animate Dead: what the creature of a raisable soul is worth, the same worth it has to summon.
## AI's own design.
static func raise_dead(target: AiTrack, slot: int) -> float:
	var soul: Soul = target.node as Soul if target.is_valid() else null
	return _worth_of_corpse(soul) if _raisable(soul, slot) else 0.0


## The raisable soul (one his side may fetch that still lies on its dead creature) within range of
## the wizard whose creature is worth most, as a track (AiSouls.soul_track), or null.
static func raise_dead_aim(caster: AiTrack, spell: SpellType, perception: AiPerception) -> AiTrack:
	var best: Soul
	var best_worth := 0.0
	for node in perception.get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if not _raisable(soul, perception.slot):
			continue
		if caster.cur_pos.distance_to(soul.global_position) > spell.cast_range_m:
			continue
		var worth := _worth_of_corpse(soul)
		if worth > best_worth:
			best_worth = worth
			best = soul
	if best == null or perception.souls == null:
		return null
	return perception.souls.soul_track(best)


## Soul Wind, Soul Mole: worth his own (a soul is one more creature for his side, like the ward's
## worth), plus, for a spell that hurts on its way (`ai_worth`, Soul Wind), the part of their health
## it takes from the known foes within `effect_range_m` of the soul. AI's own design.
static func gather_souls(
	spell: SpellType, caster: AiTrack, target: AiTrack, perception: AiPerception
) -> float:
	var soul: Soul = target.node as Soul if target.is_valid() else null
	if soul == null or not soul.fetchable_by(perception.slot):
		return 0.0
	var worth := caster.sort_key()
	if spell.ai_worth > 0:
		for foe: AiTrack in perception.bodies(AiTrack.Relation.ENEMY):
			if not AiWizardBrain.target_alive(foe):
				continue
			if foe.cur_pos.distance_to(soul.global_position) > spell.effect_range_m:
				continue
			var hp := perception.health_of(foe)
			worth += foe.sort_key() * minf(1.0, AiField.safediv(float(spell.ai_worth), float(hp.y)))
	return AiField.f32(worth)


## The soul the wizard sends for instead of walking to it: the nearest one his side may fetch, that
## no spell carries yet, farther than a short walk (soul_send_min_m, or the reach he takes souls by
## touching now when that is shorter: (1 - threat) * soul_reach_scale + soul_reach_base, the
## brain's) and inside the spell's range. As a track (AiSouls.soul_track), or null.
static func gather_souls_aim(
	caster: AiTrack, spell: SpellType, perception: AiPerception, tactics: AiTactics
) -> AiTrack:
	var reach := AiField.f32(
		(1.0 - caster.threat) * tactics.soul_reach_scale + tactics.soul_reach_base
	)
	var walk_m := minf(reach, tactics.soul_send_min_m)
	var best: Soul
	var best_d := INF
	for node in perception.get_tree().get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion():
			continue
		if not soul.fetchable_by(perception.slot):
			continue
		if soul.carrier != null and is_instance_valid(soul.carrier):
			continue
		var d := caster.cur_pos.distance_to(soul.global_position)
		if d > walk_m and d <= spell.cast_range_m and d < best_d:
			best_d = d
			best = soul
	if best == null or perception.souls == null:
		return null
	return perception.souls.soul_track(best)


## Teleport: worth his own (what the side loses with him) while his threat is at least
## `escape_threat`. AI's own design.
static func escape(caster: AiTrack, tactics: AiTactics) -> float:
	return caster.sort_key() if caster.threat >= tactics.escape_threat else 0.0


## The own building (altar, Manalith, shrine) farthest from him and beyond the reach his threat is
## measured in (senses.threat_far_m), so the jump takes him out of it. Null while the threat is
## lower or with no such building.
static func escape_aim(caster: AiTrack, perception: AiPerception, tactics: AiTactics) -> AiTrack:
	if caster.threat < tactics.escape_threat:
		return null
	var best: AiTrack
	var best_d := tactics.senses.threat_far_m
	for site: AiTrack in perception.structures(AiTrack.Relation.OWN):
		if not site.is_valid() or site.site == AiTrack.Site.FOUNT or site.site == AiTrack.Site.NONE:
			continue
		var d := caster.cur_pos.distance_to(site.cur_pos)
		if d > best_d:
			best_d = d
			best = site
	return best


## Guardian: an own creature tied to a building of his side that enemies press (at least
## guard_min_foes known foes within guard_threat_m of it, the numbers of his ward), while the
## creature is free to be tied (GuardianAction.can_guard). Worth: the creature's, 1 within
## guard_threat_m of that building and falling to 0 at senses.threat_far_m. Whether he stands near
## enough a building to cast it is the Caster's answer (Casting asks it). AI's own design.
static func guard_site(target: AiTrack, perception: AiPerception, tactics: AiTactics) -> float:
	if target.kind != AiTrack.Kind.CREATURE or target.relation != AiTrack.Relation.OWN:
		return 0.0
	if not target.is_valid() or not GuardianAction.can_guard(perception.slot, target.node):
		return 0.0
	var foes := perception.bodies(AiTrack.Relation.ENEMY)
	var best := 0.0
	for site: AiTrack in perception.structures(AiTrack.Relation.OWN):
		if not site.is_valid() or site.site == AiTrack.Site.FOUNT:
			continue
		if not _pressed(site, foes, tactics):
			continue
		var d := target.cur_pos.distance_to(site.cur_pos)
		best = maxf(best, AiField.ramp(d, tactics.guard_threat_m, tactics.senses.threat_far_m))
	return AiField.f32(target.sort_key() * best)


## Rainbow, Healing Aura: what the health a heal on an area gives back around `target` (an own or
## ally body) is worth. Each own or ally body within the spell's reach (`effect_range_m`) of it that
## misses health, is not being summoned and has no heal running on it (like `heal`) counts its worth
## times the part of its health it misses; nothing when together they miss less than
## heal_area_min_missing. It reads the health the side knows. AI's own design.
static func heal_area(
	spell: SpellType, target: AiTrack, perception: AiPerception, tactics: AiTactics
) -> float:
	var friend := (
		target.relation == AiTrack.Relation.OWN or target.relation == AiTrack.Relation.ALLY
	)
	if not target.is_body() or not friend:
		return 0.0
	var missing := 0
	var worth := 0.0
	for relation in [AiTrack.Relation.OWN, AiTrack.Relation.ALLY]:
		for body: AiTrack in perception.bodies(relation):
			if not AiWizardBrain.target_alive(body):
				continue
			if body.cur_pos.distance_to(target.cur_pos) > spell.effect_range_m:
				continue
			if body.node is UnitBody and (body.node as UnitBody).is_summoning():
				continue
			# a heal already runs on it (the rule of `heal`)
			if body.node.get_node_or_null(HealEffect.NODE_NAME) != null:
				continue
			var hp := perception.health_of(body)
			if hp.y <= 0 or hp.x >= hp.y:
				continue
			missing += hp.y - hp.x
			worth += body.sort_key() * AiField.safediv(float(hp.y - hp.x), float(hp.y))
	return AiField.f32(worth) if float(missing) >= tactics.heal_area_min_missing else 0.0


## Whether the spell's own target rule takes a creature of no player (no rule known: yes, the
## Caster decides).
static func _takes_neutral(spell: SpellType, caster: AiTrack) -> bool:
	var casting: Caster = Caster.of(caster.node) if caster.is_valid() else null
	var action: CarrierAction = null
	if casting != null:
		action = casting.action_for(spell.tag) as CarrierAction
	return action == null or action.target == null or action.target.neutral_allowed


## At least guard_min_foes of `foes` stand within guard_threat_m of `site` (where the side believes
## they are).
static func _pressed(site: AiTrack, foes: Array, tactics: AiTactics) -> bool:
	var count := 0
	for foe: AiTrack in foes:
		if not AiWizardBrain.target_alive(foe):
			continue
		if foe.cur_pos.distance_to(site.cur_pos) <= tactics.guard_threat_m:
			count += 1
	return count >= tactics.guard_min_foes


## A soul `slot` may fetch that still holds its dead creature (the rule of AnimateDeadAction.check).
static func _raisable(soul: Soul, slot: int) -> bool:
	if soul == null or not is_instance_valid(soul) or soul.is_queued_for_deletion():
		return false
	if not soul.fetchable_by(slot):
		return false
	var corpse := soul.corpse as UnitBody
	return corpse != null and is_instance_valid(corpse) and corpse.is_dead()


## What the dead creature of `soul` is worth (AiTrackFacts.tag_acc, the rating of its type).
static func _worth_of_corpse(soul: Soul) -> float:
	var corpse: UnitBody = soul.corpse as UnitBody if soul != null else null
	if corpse == null or not is_instance_valid(corpse) or corpse.type == null:
		return 0.0
	return AiRater.rate(AiTrackFacts.tag_acc(corpse.type))
