@tool
class_name AiWizardCasting
extends Node

## How the AI's wizard casts what his phases queued: the best entry he can pay that the Caster would accept (its answer to that click,
## for every spell); out of reach he walks toward it, else the entry is skipped (a forced one he cannot afford waits). It also keeps
## the difficulty's summon pace (`pace`). It does not rate spells (AiSpellEval) nor fill the queue (the phases).
## Ref: shiny.d:3201-3280 executeBestCast, 3174-3199 lightCanCast.

@export var perception: AiPerception
@export var stance: AiStance
@export var port: AiCommandPort
const CASTER := preload("res://scenes/spells/caster.gd")

var eval: AiSpellEval
var shots: AiShotCheck
var futile: AiFutileTargets
var casts_started := 0
var heal_skips := 0  # F372: queued Heals skipped because the body no longer needs them
var pace := AiSummonPace.new()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if perception and stance and port else PackedStringArray(["Faltan los sockets perception, stance o port."])


func prepare(p_eval: AiSpellEval, p_tactics: AiTactics) -> void:
	eval = p_eval
	shots = AiShotCheck.new(eval, port, p_tactics)
	futile = AiFutileTargets.new(perception, port, p_tactics)


## lightCanCast: mana, souls, cooldown and a free wizard, with the Caster's own mana test (never «Sin maná»).
func light_can_cast(wizard: AiTrack, spell: Resource) -> bool:
	var node := wizard.node as WizardBody
	if not node.can_cast():
		return false
	## a cast decided and waiting its delay (Easy, 024e) keeps him busy like one being cast
	if port != null and port.cast_pending():
		return false
	if AiBody.caster(node).is_casting():
		return false
	var book := AiBody.spellbook(node)
	var cooldown := 0.0
	if spell is CreatureType:
		if AiBody.souls(node) < (spell as CreatureType).souls:
			return false
		cooldown = book.creature_cooldown(book.creature_index_of((spell as CreatureType).tag))
	elif spell is SpellType:
		var tag := (spell as SpellType).tag
		if bool((spell as SpellType).is_structure):
			cooldown = book.structure_cooldown(book.structure_index_of(tag))
		else:
			cooldown = book.cooldown(book.index_of(tag))
	else:
		return false
	if cooldown > 0.0:
		return false
	var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
	return cost <= AiBody.mana_now(node) + CASTER.MANA_EPSILON


## 024e: what a cast that waited its delay (Easy) checks again when it leaves the port: lightCanCast and the Caster's own answer
## (AiCastOut.status), so the half second never turns into a refusal. Returns "" when it can go, else why not.
func cast_refusal(wizard: AiTrack, spell: Resource, target: AiTrack, point: Vector3) -> String:
	if not light_can_cast(wizard, spell):
		return "lightCanCast"
	return port.casts.status(spell, target, point)


## enqueueForcedExecute: score 0, forced, and straight to the execution. Ref: shiny.d:3290 (0x48d080).
func enqueue_forced_execute(wizard: AiTrack, target: AiTrack, spell: Resource, range_m: float, obj: AiTrack) -> int:
	AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(AiCastQueue.FORCED, 0.0, target, spell, range_m, obj))
	return execute_best_cast(wizard, false)


## executeBestCast. `check_only` is the soul-pickup test (what he can cast in passing). Returns 1 when he cast or walked.
func execute_best_cast(wizard: AiTrack, check_only: bool) -> int:
	var queue := wizard.cast_queue
	var i := 0
	while i < queue.size():
		var e: Dictionary = queue[i]
		var forced := (int(e["flag"]) & AiCastQueue.FORCED) != 0
		var target: AiTrack = e["target"]
		var obj: AiTrack = e["obj"]
		var spell: Resource = e["spell"]
		if spell == null or (forced and target != null and check_only):
			i += 1
			continue
		## No Manalith: only what the wizard can pay now (shiny.d:3216-3224).
		if stance.manalith_count() == 0:
			var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
			if cost > AiBody.mana_now(wizard.node) + CASTER.MANA_EPSILON:
				if forced:
					return 0
				i += 1
				continue
		if target != null and not AiWizardBrain.target_alive(target):
			i += 1
			continue
		## F372 (RFC-053 053c): a Heal is scored again against the health the side knows now; one no longer needed is skipped.
		if target != null and not eval.still_worth(spell, target):
			heal_skips += 1
			i += 1
			continue
		if obj != null:
			if target != null and target.kind == AiTrack.Kind.WIZARD and (target.node as WizardBody).is_ghost():
				i += 1
				continue
			var range_m := float(e["range"])
			if wizard.cur_pos.distance_squared_to(obj.cur_pos) > range_m * range_m:
				if not check_only:
					port.orders.order_pos_radius(wizard, AiCommandPort.AiOrder.MOVE_NEAR, obj.cur_pos, range_m)
					return 1
				i += 1
				continue
		if not light_can_cast(wizard, spell):
			if not forced:
				i += 1
				continue
			if obj == null:
				return 0
			if not check_only:
				port.orders.order_target_radius(wizard, AiCommandPort.AiOrder.GUARD, obj, float(e["range"]))
				return 1
			i += 1
			continue
		## Without perfect information (024e) a body the side does not see now cannot be clicked: the entry is skipped.
		if target != null and not port.can_aim(target):
			i += 1
			continue
		## F371: the line of fire and sight (shiny.d:3254-3270) and the burst on his own bodies.
		var shot := shots.check(wizard, target, spell, check_only)
		if shot == AiShotCheck.Shot.WALKED and not check_only:
			return 1
		if shot != AiShotCheck.Shot.OK:
			i += 1
			continue
		var point := obj.cur_pos if obj != null else wizard.cur_pos
		if not port.casts.status(spell, target, point).is_empty():
			i += 1
			continue
		port.start_casting(spell, target, point)
		casts_started += 1
		futile.note_cast(spell, target)
		if spell is CreatureType:
			pace.note_summon(port.now_tick())
		queue.remove_at(i)
		return 1
	return 0
