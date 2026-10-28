class_name AiWizardBrain
extends Node

## The brain of the AI's wizard. The task board calls `think` for the wizard when a record asks for
## it. Every 16 ticks of his age he replans: the weights of attacking, supporting and converting,
## the queue is emptied and every phase child fills it again. Then, in order: the souls he can take
## by touching them (within (1 - threat) * 100 + 80 m), the capture branch of a record of the
## capture task (Desecrate an enemy altar, or a Manalith on a free fount), the best cast he can pay
## (the child Casting), else he thinks like a creature. A ghost waits for his Manahoars or goes to
## the nearest mana building. It does not rate spells (AiSpellEval) nor talk to the game (the port).

## What one `think` did.
enum Thought {
	## Nothing to do: the caller may let the record's leader or the body's own aggression decide.
	NOTHING,
	## He gave an order or cast.
	ACTED,
	## He started a capture cast (Desecrate or Manalith) at the target of his capture record.
	CAPTURING,
}

## A capture cast that starts waits this many more re-issue periods before the next one.
const CAPTURE_REISSUE_WAIT := 7

@export var perception: AiPerception
@export var stance: AiStance
@export var groups: AiGroups
@export var port: AiCommandPort
@export var creature_brain: CreatureBrain
## The child that walks the cast queue and casts.
@export var casting: AiWizardCasting

var rng := AiRand.new()
var eval: AiSpellEval
var phases: Array[AiPhase] = []
## What the side plays with: tactics, aggression, ages (AiSide.setup sets it once, before
## prepare).
var play: AiPlay


func _ready() -> void:
	for child in get_children():
		if child is AiPhase:
			(child as AiPhase).brain = self
			phases.append(child)


## Called by AiSide.setup once `play` is set.
func prepare() -> void:
	eval = AiSpellEval.new(perception, stance, groups, play.tactics)
	casting.prepare(eval, play)


func think(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> Thought:
	if not wizard.is_valid():
		return Thought.NOTHING
	if (wizard.node as WizardBody).is_ghost():
		return _ghost(wizard, task_kind, record)
	# A cast decided and waiting its delay (Easy): he stands as if casting and orders nothing else
	# (else he walked on toward the fount and stood on it when the Manalith left: «Sin lugar»).
	if port.cast_pending():
		return Thought.ACTED
	if wizard.spell_dirty:
		rebuild_spells(wizard)
	var tactics := play.tactics
	if wizard.age >= wizard.next_replan:
		wizard.next_replan = wizard.age + play.ages_for(tactics.wizard_replan_s)
		wizard.next_reissue = wizard.age - 1
		var w3 := AiField.weight_triple(task_kind, stance.enemy_ratio(), play.aggression)
		wizard.cast_queue.clear()
		var capture_record := record if task_kind == AiTask.Kind.CAPTURE else null
		for phase in phases:
			phase.run(wizard, w3, capture_record)
	# Souls he can take by touching (retail: 100 + 80 m scaled by the threat; the beta 80 + 60):
	# first what he can cast in passing, else he walks onto the soul.
	var reach := AiField.f32(
		(1.0 - wizard.threat) * tactics.soul_reach_scale + tactics.soul_reach_base
	)
	if wizard.ord_state == AiCommandPort.AiOrder.TAKE_SOUL:
		reach *= tactics.soul_keep_factor
	var soul := perception.find_best_near(wizard.cur_pos, reach, true)
	if soul != null:
		if not casting.execute_best_cast(wizard, true):
			port.orders.order_go_to(wizard, AiCommandPort.AiOrder.TAKE_SOUL, soul.cur_pos)
		return Thought.ACTED
	if record != null and task_kind == AiTask.Kind.CAPTURE:
		if _capture(wizard, record):
			return Thought.CAPTURING
	if casting.execute_best_cast(wizard, false):
		return Thought.ACTED
	# max-returns: one return per decision, in priority order.
	# gdlint: ignore=max-returns
	return _as_creature(wizard, task_kind, record)


## A target that still exists and is not dying (the Caster would answer "Blanco inválido").
static func target_alive(t: AiTrack) -> bool:
	if t == null or not t.is_valid():
		return false
	return not AiBody.is_dead(t.node)


## The book of the wizard in the lists the phases read.
func rebuild_spells(wizard: AiTrack) -> void:
	wizard.summons = []
	wizard.spell_accs = []
	wizard.manahoar_spell = null
	wizard.shrine_spell = null
	wizard.convert_spell = null
	wizard.desecrate_spell = null
	var book := AiBody.spellbook(wizard.node)
	for i in book.creature_count():
		var type := book.creature_at(i)
		if type == null:
			continue
		if type.has_passive(perception.mana_source):
			wizard.manahoar_spell = type
		else:
			wizard.summons.append({"tag": type.tag, "type": type, "acc": perception.tag_acc(type)})
	for i in book.size():
		var spell := book.spell_at(i)
		if spell != null and AiSpellEval.wants_acc(spell):
			wizard.spell_accs.append({"spell": spell})
	for i in book.structure_count():
		var spell := book.structure_at(i)
		if spell == null:
			continue
		# a structure-tab spell with a phase (Teleport, Guardian) is rated like any other
		if AiSpellEval.wants_acc(spell):
			wizard.spell_accs.append({"spell": spell})
		if wizard.shrine_spell == null and spell.only_free_manafounts:
			wizard.shrine_spell = spell
		if spell.ai_use == SpellType.AiUse.CONVERT:
			wizard.convert_spell = spell
		if spell.ai_use == SpellType.AiUse.DESECRATE:
			wizard.desecrate_spell = spell
	wizard.spell_dirty = false


## The ghost: his own Manahoars within ghost_wait_m will channel him back, so he waits; with none
## near he goes to the nearest mana building of his side (altar, Manalith). That last part is a
## deliberate deviation from the original.
func _ghost(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> Thought:
	var wait_m := play.tactics.ghost_wait_m
	for t: AiTrack in perception.bodies(AiTrack.Relation.OWN):
		if t.kind != AiTrack.Kind.MANAHOAR:
			continue
		if wizard.cur_pos.distance_squared_to(t.cur_pos) <= wait_m * wait_m:
			return _as_creature(wizard, task_kind, record)
	var best: AiTrack
	var best_d := INF
	for t: AiTrack in perception.structures(AiTrack.Relation.OWN):
		if not t.is_valid() or not (t.is_altar() or t.site == AiTrack.Site.MANALITH):
			continue
		var d := wizard.cur_pos.distance_squared_to(t.cur_pos)
		if d < best_d:
			best_d = d
			best = t
	if best != null:
		port.orders.order_if_changed(wizard, AiCommandPort.AiOrder.GUARD, best, null)
		return Thought.ACTED
	return _as_creature(wizard, task_kind, record)


func _as_creature(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> Thought:
	if creature_brain.think(wizard, task_kind, record):
		return Thought.ACTED
	return Thought.NOTHING


## Every 8 ages, at the target of his capture record, Desecrate (an altar) or Manalith (a free
## fount). It does not choose the record (CaptureTask does) and it does not pay or check the cast
## (Casting does). Returns true when it started the cast.
func _capture(wizard: AiTrack, record: AiRecord) -> bool:
	var tn := record.target
	if tn == null or wizard.age < wizard.next_reissue:
		return false
	var reissue := play.ages_for(play.tactics.wizard_reissue_s)
	wizard.next_reissue = wizard.age + reissue
	if tn.is_altar():
		if _desecrate(wizard, tn):
			wizard.next_reissue += CAPTURE_REISSUE_WAIT * reissue
			return true
		return false
	if tn.capturable() and tn.free_fount:
		return _build_on_fount(wizard, tn)
	return false


## The desecrate path: an enemy altar not under ritual, the creature with most souls brought next to
## the wizard, and the altar being the closest enemy one in range.
func _desecrate(wizard: AiTrack, altar: AiTrack) -> bool:
	if wizard.desecrate_spell == null or altar.relation != AiTrack.Relation.ENEMY:
		return false
	if perception.desecration_against(altar):
		return false
	var guard := _pick_guard_creature(altar)
	if guard == null or perception.closest_enemy_altar_in_range() != altar.node:
		return false
	var spell: SpellType = wizard.desecrate_spell
	var radius := AiField.f32(spell.cast_range_m * play.tactics.desecrate_range_factor)
	if not port.orders.order_target_radius(guard, AiCommandPort.AiOrder.GUARD, wizard, radius):
		return false
	return casting.enqueue_forced_execute(wizard, guard, spell, spell.cast_range_m, null)


## Of the own creatures (not the wizard) the one that weighs most (1 within guard_pick_near_m of the
## target, falling linearly to 0 at guard_pick_far_m; the scale is 1/(far - near) rounded to
## float32, as the original's constant 0.00027700831) times its souls; a strict argmax from 0, so a
## creature of 0 souls is never picked. Deviation: the game's own test `sacrifice_status` (alive,
## free, not held, a Captive) filters the candidates first, so the AI never asks Desecrate for a
## creature that would answer «Blanco inválido». A creature bound by the Guardian spell is skipped.
func _pick_guard_creature(target: AiTrack) -> AiTrack:
	var best := 0.0
	var best_track: AiTrack
	var system := perception.sacrifice()
	var near := play.tactics.crowd.guard_pick_near_m
	var far := play.tactics.crowd.guard_pick_far_m
	var scale := AiField.f32(1.0 / (far - near))
	for c: AiTrack in perception.bodies(AiTrack.Relation.OWN):
		if c.kind == AiTrack.Kind.WIZARD or not c.is_valid():
			continue
		# a creature bound to a building by the Guardian spell is never the victim
		if c.is_guardian_bound():
			continue
		if system != null and not system.sacrifice_status(perception.slot, c.node).is_empty():
			continue
		var worth := AiGroups.souls_pair(c).x
		var d := c.extrap_pos.distance_to(target.cur_pos)
		var w := 0.0
		if d <= near:
			w = 1.0
		elif d < far:
			w = (far - d) * scale
		var v := w * float(worth)
		if best < v:
			best = v
			best_track = c
	if best_track != null and best_track.group != null:
		(best_track.group as AiGroup).members.erase(best_track)
		best_track.group = null
	return best_track


## The Manalith spell, forced, when the wizard is within range * sqrt(build_range_slack) *
## build_reach_factor of the fount and the threat is under build_threat_cap. The fount must still be
## free (the Manalith spell's check reads it live).
func _build_on_fount(wizard: AiTrack, fount: AiTrack) -> bool:
	var shrine: SpellType = wizard.shrine_spell
	var tactics := play.tactics
	if shrine == null or wizard.threat >= tactics.build_threat_cap:
		return false
	if not fount.is_valid() or not (fount.node as ManafountBody).is_free():
		return false
	var r := float(shrine.cast_range_m)
	r = (
		r
		* r
		* tactics.build_range_slack
		* (tactics.build_reach_factor * tactics.build_reach_factor)
	)
	if wizard.cur_pos.distance_squared_to(fount.cur_pos) > r:
		return false
	return casting.enqueue_forced_execute(wizard, fount, shrine, shrine.cast_range_m, null)
