@tool
class_name AiWizardCasting
extends Node

## How the AI's wizard casts what his phases queued: the best entry he can pay that the Caster would
## accept (its answer to that click, for every spell); out of reach he walks toward it, else the
## entry is skipped (a forced one he cannot afford waits). Before an attack spell it checks the
## shot: only with a clear line (else he walks `los_retry_factor` of the way and tries again), and a
## splash spell is held back when its burst would take more than `own_splash_max_ratio` of an own
## body. It also keeps the difficulty's summon pace (a summon only every `summon_interval_ticks`,
## leaving `mana_reserve`) and bans the bodies his attack spells do not bring down. It does not rate
## spells (AiSpellEval) nor fill the queue (the phases).

## What the shot check answers: cast, walked closer for a clear line, or skip the entry.
enum Shot { OK, WALKED, VETOED }

const CASTER := preload("res://scenes/spells/caster.gd")
## Squared meters: within this of the spot he walks to for a clear line, the walk is chosen again.
const LINE_GOAL_REACHED_SQ := 4.0

@export var perception: AiPerception
@export var stance: AiStance
@export var port: AiCommandPort

var eval: AiSpellEval
var tactics: AiTactics
var casts_started := 0
## Queued Heals skipped because the body no longer needs them.
var heal_skips := 0
## The difficulty's own summon pace (Easy): physics ticks between two summons and the fraction of
## his pool he keeps. 0 and 0 = the original (Normal, Hard). Set by prepare.
var summon_interval_ticks := 0
var mana_reserve := 0.0
## Diagnostic: casts held back for want of a clear line (he walked closer) and for the burst they
## would take from his own bodies; bodies banned as futile spell targets.
var line_walks := 0
var splash_vetoes := 0
var futile_bans := 0

## The port tick of the last summon he started (the summon interval counts from it).
var _last_summon_tick := -1000000
## The walk toward a target he has no clear line to (its track id and where he was sent), kept
## while he walks to it.
var _line_target := 0
var _line_goal := Vector3.ZERO
## Track id -> [the health the side knew at the last attack cast, tick its ban ends or 0].
var _attack_marks: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	if perception and stance and port:
		return PackedStringArray()
	return PackedStringArray(["Missing the perception, stance or port socket."])


## Called by AiWizardBrain.prepare once the side's play is known.
func prepare(p_eval: AiSpellEval, play: AiPlay) -> void:
	eval = p_eval
	tactics = play.tactics
	summon_interval_ticks = play.difficulty.summon_interval_ticks(Engine.physics_ticks_per_second)
	mana_reserve = play.difficulty.mana_reserve


## lightCanCast: mana, souls, cooldown and a free wizard, with the Caster's own mana test (never
## «Sin maná»).
func light_can_cast(wizard: AiTrack, spell: Resource) -> bool:
	var node := wizard.node as WizardBody
	if not node.can_cast():
		return false
	# a cast decided and waiting its delay (Easy) keeps him busy like one being cast
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
		if (spell as SpellType).is_structure:
			cooldown = book.structure_cooldown(book.structure_index_of(tag))
		else:
			cooldown = book.cooldown(book.index_of(tag))
	else:
		return false
	if cooldown > 0.0:
		return false
	var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
	return cost <= AiBody.mana_now(node) + CASTER.MANA_EPSILON


## What a cast that waited its delay (Easy) checks again when it leaves the port: lightCanCast and
## the Caster's own answer (AiCommandPort.cast_status), so the half second never turns into a
## refusal. Returns "" when it can go, else why not.
func cast_refusal(wizard: AiTrack, spell: Resource, target: AiTrack, point: Vector3) -> String:
	if not light_can_cast(wizard, spell):
		return "lightCanCast"
	return port.cast_status(spell, target, point)


## Score 0, forced, and straight to the execution. Returns true when he cast
## or walked.
func enqueue_forced_execute(
	wizard: AiTrack, target: AiTrack, spell: Resource, range_m: float, obj: AiTrack
) -> bool:
	AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(true, 0.0, target, spell, range_m, obj))
	return execute_best_cast(wizard, false)


## `check_only` is the soul-pickup test (what he can cast in passing). Returns true
## when he cast or walked.
func execute_best_cast(wizard: AiTrack, check_only: bool) -> bool:
	var queue := wizard.cast_queue
	var i := 0
	while i < queue.size():
		var e: Dictionary = queue[i]
		var forced: bool = e["forced"]
		var target: AiTrack = e["target"]
		var obj: AiTrack = e["obj"]
		var spell: Resource = e["spell"]
		if spell == null or (forced and target != null and check_only):
			i += 1
			continue
		# No Manalith: only what the wizard can pay now.
		if stance.manalith_count() == 0:
			var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
			if cost > AiBody.mana_now(wizard.node) + CASTER.MANA_EPSILON:
				if forced:
					return false
				i += 1
				continue
		if target != null and not AiWizardBrain.target_alive(target):
			i += 1
			continue
		# A Heal is scored again against the health the side knows now; one no longer needed is
		# skipped.
		if target != null and not eval.still_worth(spell, target):
			heal_skips += 1
			i += 1
			continue
		if obj != null:
			var ghost := target != null and target.kind == AiTrack.Kind.WIZARD
			if ghost and (target.node as WizardBody).is_ghost():
				i += 1
				continue
			var range_m := float(e["range"])
			if wizard.cur_pos.distance_squared_to(obj.cur_pos) > range_m * range_m:
				if not check_only:
					port.orders.order_pos_radius(
						wizard, AiCommandPort.AiOrder.MOVE_NEAR, obj.cur_pos, range_m
					)
					return true
				i += 1
				continue
		if not light_can_cast(wizard, spell):
			if not forced:
				i += 1
				continue
			if obj == null:
				return false
			if not check_only:
				port.orders.order_target_radius(
					wizard, AiCommandPort.AiOrder.GUARD, obj, float(e["range"])
				)
				return true
			i += 1
			continue
		# Without perfect information a body the side does not see now cannot be clicked: the entry
		# is skipped.
		if target != null and not port.can_aim(target):
			i += 1
			continue
		# The line of fire and sight and the burst on his own bodies.
		var shot := _check_shot(wizard, target, spell, check_only)
		if shot == Shot.WALKED and not check_only:
			return true
		if shot != Shot.OK:
			i += 1
			continue
		var point := obj.cur_pos if obj != null else wizard.cur_pos
		if not port.cast_status(spell, target, point).is_empty():
			i += 1
			continue
		port.start_casting(spell, target, point)
		casts_started += 1
		_note_attack(spell, target)
		if spell is CreatureType:
			_last_summon_tick = port.now_tick()
		queue.remove_at(i)
		return true
	return false


## The summon interval has passed since his last summon (always true with interval 0).
func summon_interval_over() -> bool:
	if summon_interval_ticks <= 0:
		return true
	return port.now_tick() - _last_summon_tick >= summon_interval_ticks


## A creature of `mana_cost` leaves him at least the reserve (always true with reserve 0).
func keeps_mana_reserve(wizard: AiTrack, mana_cost: float) -> bool:
	if mana_reserve <= 0.0:
		return true
	return AiBody.mana_now(wizard.node) - mana_cost >= mana_reserve * AiBody.mana_max(wizard.node)


## A body the side's attack spells do not bring down is not a spell target until its ban ends
## (`spell_futile_forget_s`).
func is_futile(target: AiTrack) -> bool:
	var mark: Array = _attack_marks.get(target.id, [])
	if mark.is_empty() or int(mark[1]) == 0:
		return false
	if port.now_tick() < int(mark[1]):
		return true
	_attack_marks.erase(target.id)
	return false


## OK (cast), WALKED (no clear line: sent closer, but not when `check_only`) or VETOED (skip the
## entry).
func _check_shot(wizard: AiTrack, target: AiTrack, spell: Resource, check_only: bool) -> Shot:
	if not (spell is SpellType) or target == null or not target.is_valid():
		return Shot.OK
	if target.node == wizard.node:
		return Shot.OK
	var type := spell as SpellType
	if type.is_structure or not AiSpellEval.casts_in(type, SpellType.AiPhase.ATTACK):
		return Shot.OK
	var body := wizard.node as WizardBody
	var splash := AiLineOfFire.is_splash(body, type)
	if not tactics.los_check and not splash:
		return Shot.OK
	var line := AiLineOfFire.trace(body, target.node, type)
	var blocker: Node3D = line["blocker"]
	if tactics.los_check and blocker != null:
		if not check_only:
			_walk_for_line(wizard, target)
		return Shot.WALKED
	_line_target = 0
	if splash:
		var direct := blocker if blocker != null else target.node
		var loss := AiAreaRating.own_splash(line["point"], type, direct, perception, tactics)
		if loss > tactics.own_splash_max_ratio:
			splash_vetoes += 1
			return Shot.VETOED
	return Shot.OK


## Walks `los_retry_factor` of the distance to where the side knows the target; while he walks to
## that spot it is not moved.
func _walk_for_line(wizard: AiTrack, target: AiTrack) -> void:
	var walking := (wizard.node as WizardBody).is_walking()
	var reached := wizard.cur_pos.distance_squared_to(_line_goal) <= LINE_GOAL_REACHED_SQ
	if _line_target != target.id or not walking or reached:
		_line_goal = wizard.cur_pos.lerp(target.cur_pos, tactics.los_retry_factor)
		_line_target = target.id
	line_walks += 1
	port.orders.order_go_to(wizard, AiCommandPort.AiOrder.MOVE_NEAR, _line_goal)


## An attack spell started on a body: if what it lost since the last one (the health the side
## knows), spell_kill_max_casts times over, would not bring it down, it is banned for
## spell_futile_forget_s.
func _note_attack(spell: Resource, target: AiTrack) -> void:
	if tactics == null or tactics.spell_futile_forget_s <= 0.0:
		return
	if target == null or not target.is_body() or not (spell is SpellType):
		return
	var type := spell as SpellType
	if type.is_structure or not AiSpellEval.casts_in(type, SpellType.AiPhase.ATTACK):
		return
	var health := perception.health_of(target)
	var mark: Array = _attack_marks.get(target.id, [])
	if DebugLog.on(&"ai_attack"): print(
			(
				"ai_attack slot %d spell %s on %s: known health %d of %d, before %s, seen %s"
				% [
					perception.slot,
					type.tag,
					target.node.name,
					health.x,
					health.y,
					str(mark[0]) if not mark.is_empty() else "-",
					str(perception.knows_live(target)),
				]
			)
		)
	var lost_too_little := false
	if not mark.is_empty() and health.y > 0:
		lost_too_little = (int(mark[0]) - health.x) * tactics.spell_kill_max_casts < health.x
	if lost_too_little:
		mark[1] = port.now_tick() + MatchClock.ticks_for(tactics.spell_futile_forget_s)
		futile_bans += 1
		if DebugLog.on(&"ai_attack"): print(
				(
					"ai_attack slot %d futile spell on %s: health %d before %d of %d"
					% [perception.slot, target.node.name, health.x, int(mark[0]), health.y]
				)
			)
	else:
		mark = [health.x, 0]
	mark[0] = health.x
	_attack_marks[target.id] = mark
