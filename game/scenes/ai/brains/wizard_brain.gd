class_name AiWizardBrain
extends Node

## The brain of the AI's wizard. The task board calls `think` for the wizard when a record asks for it. Every 16 ticks of his
## age he replans: the weights of attacking, supporting and converting, the queue is emptied and every phase child fills it
## again. Then, in order: the souls he can take by touching them (within (1 - threat) * 100 + 80 m), the capture branch of a
## record of the capture task (AiCaptureCasts), the best cast he can pay (the child Casting), else he thinks like a creature.
## A ghost waits for his Manahoars or goes to the nearest mana building. It does not rate spells (AiSpellEval) nor talk to the
## game (the port). Ref: shiny.d:3303-3387 wizBrain, 3330-3337 souls; RFC-024 §3.1.

## After a replan of the wizard: the cast queue the phases left (diagnostic: the bench's decision log listens; nothing in the game does).
signal replanned(wizard: AiTrack, queue: Array)

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
## What the side plays with: tactics, aggression, ages (AiSide.setup sets it once, before prepare).
var play: AiPlay
var capture: AiCaptureCasts


func _ready() -> void:
	for child in get_children():
		if child is AiPhase:
			(child as AiPhase).brain = self
			phases.append(child)


## Called by AiSide.setup once `play` is set.
func prepare() -> void:
	casting.pace.interval_ticks = play.difficulty.summon_interval_ticks(Engine.physics_ticks_per_second)
	casting.pace.mana_reserve = play.difficulty.mana_reserve
	eval = AiSpellEval.new(perception, stance, groups, play.tactics)
	casting.prepare(eval, play.tactics)
	capture = AiCaptureCasts.new(perception, port, play, casting)


## wizBrain (shiny.d:3303-3387). Returns 1 when it gave an order or cast, 2 when it started a capture cast, 0 when it had nothing to do.
func think(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> int:
	if not wizard.is_valid():
		return 0
	if (wizard.node as WizardBody).is_ghost():
		return _ghost(wizard, task_kind, record)
	## A cast decided and waiting its delay (Easy, 024e): he stands as if casting and orders nothing else (else he walked on toward
	## the fount and stood on it when the Manalith left: «Sin lugar»).
	if port.cast_pending():
		return 1
	if wizard.spell_dirty:
		rebuild_spells(wizard)
	var tactics := play.tactics
	if wizard.age >= wizard.next_replan:
		wizard.next_replan = wizard.age + play.ages_for(tactics.wizard_replan_s)
		wizard.next_reissue = wizard.age - 1
		var w3 := AiField.weight_triple(task_kind, stance.enemy_ratio(), play.aggression)
		wizard.cast_queue.clear()
		for phase in phases:
			phase.run(wizard, w3, record if task_kind == AiTask.Kind.CAPTURE else null)
		replanned.emit(wizard, wizard.cast_queue)
	## Souls he can take by touching (retail: 100 + 80 m scaled by the threat; the beta 80 + 60): first what he can cast in passing
	## (checkOnly), else he walks onto the soul.
	var reach := AiField.f32((1.0 - wizard.threat) * tactics.soul_reach_scale + tactics.soul_reach_base)
	if wizard.ord_state == AiCommandPort.AiOrder.TAKE_SOUL:
		reach *= tactics.soul_keep_factor
	var soul := perception.find_best_near(wizard.cur_pos, reach, true)
	if soul != null:
		if casting.execute_best_cast(wizard, true) != 0:
			return 1
		port.orders.order_go_to(wizard, AiCommandPort.AiOrder.TAKE_SOUL, soul.cur_pos)
		return 1
	if record != null and task_kind == AiTask.Kind.CAPTURE:
		var captured := capture.run(wizard, record)
		if captured != 0:
			return captured
	if casting.execute_best_cast(wizard, false) != 0:
		return 1
	return creature_brain.think(wizard, task_kind, record)


## The ghost (shiny.d:3306-3326): his own Manahoars within ghost_wait_m will channel him back, so he waits; with none near he goes to the
## nearest mana building of his side (altar, Manalith). That last part is a deliberate deviation of sacengine, not of thaum.
func _ghost(wizard: AiTrack, task_kind: AiTask.Kind, record: AiRecord) -> int:
	var wait_m := play.tactics.ghost_wait_m
	for t: AiTrack in perception.bodies(0):
		if t.kind == AiTrack.Kind.MANAHOAR and wizard.cur_pos.distance_squared_to(t.cur_pos) <= wait_m * wait_m:
			return creature_brain.think(wizard, task_kind, record)
	var best: AiTrack
	var best_d := INF
	for t: AiTrack in perception.structures(0):
		if not t.is_valid() or not (t.is_altar() or t.site == AiTrack.Site.MANALITH):
			continue
		var d := wizard.cur_pos.distance_squared_to(t.cur_pos)
		if d < best_d:
			best_d = d
			best = t
	if best != null:
		port.orders.order_if_changed(wizard, AiCommandPort.AiOrder.GUARD, best, null)
		return 1
	return creature_brain.think(wizard, task_kind, record)


## A target that still exists and is not dying (the Caster would answer "Blanco inválido").
static func target_alive(t: AiTrack) -> bool:
	if t == null or not t.is_valid():
		return false
	return not AiBody.is_dead(t.node)


## wizSpellRebuild (shiny.d:2610-2636): the book of the wizard in the lists the phases read.
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
			wizard.spell_accs.append({"spell": spell, "fn": AiSpellEval.rating_fn(spell)})
	for i in book.structure_count():
		var spell := book.structure_at(i)
		if spell == null:
			continue
		if AiSpellEval.wants_acc(spell):  # 055f f5: a structure-tab spell with a phase (Teleport, Guardian) is rated like any other
			wizard.spell_accs.append({"spell": spell, "fn": AiSpellEval.rating_fn(spell)})
		if wizard.shrine_spell == null and spell.only_free_manafounts:
			wizard.shrine_spell = spell
		if spell.ai_use == SpellType.AiUse.CONVERT:
			wizard.convert_spell = spell
		if spell.ai_use == SpellType.AiUse.DESECRATE:
			wizard.desecrate_spell = spell
	wizard.spell_dirty = false
