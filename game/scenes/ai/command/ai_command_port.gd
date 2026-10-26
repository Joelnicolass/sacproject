class_name AiCommandPort
extends Node

## The only way out of the AI into the game (RULES.md «IA»): a cast is the Caster call of a human's click (AiCastOut), an order
## goes through the child `orders` (AiOrdersOut). So the AI pays mana and souls, waits for the cooldowns and cannot order what is
## not its own; it never touches a body, a pool or a purse. Only where the game is simulated (solo or the server): no RPC.
## 024e (AiDifficulty): with a delay (Easy) every request waits `delay_ticks`, as a human's hand does; a waiting cast keeps the
## wizard busy and goes out only if it still can be paid and its target still lives (else it lapses, never a refusal). In no
## difficulty a request takes a body of another side the side does not see now. Ref: RFC-024 §3.1.

## What a brain asks a body to do (`ostate`). The numbers are the original's order states and show in the logs.
##   MOVE_NEAR  walk to within a radius of a point        GUARD    stay near a body (or a place) and fight what comes
##   MOVE       walk to a point (the anchor of a record)  REFILL   stay by a body or a mana source (retreat, autoCapture)
##   ATTACK     attack a body                             ADVANCE  advance to a point, fighting on the way
##   TAKE_SOUL  the wizard walks onto a soul
enum AiOrder { MOVE_NEAR = 2, GUARD = 3, MOVE = 4, REFILL = 5, ATTACK = 6, ADVANCE = 7, TAKE_SOUL = 34 }

@export var audit: AiAudit:
	set(value):
		audit = value
		if orders != null:
			orders.audit = value
@export var perception: AiPerception
## The orders of the AI (child `Orders`).
@export var orders: AiOrdersOut

var slot := 0
var wizard: WizardBody
var casts := AiCastOut.new()
## 024e: physics ticks between a decision and its request (AiDifficulty.request_delay_s); 0 = at once.
var delay_ticks := 0:
	set(value):
		delay_ticks = value
		if orders != null:
			orders.delay_ticks = value
## The wizard brain's own test (lightCanCast and the rules of the rituals), checked again when a delayed cast leaves: (track, spell, target, point) -> "" or why not.
var can_cast: Callable
## Delayed casts that did not leave (they could no longer be paid or their target died meanwhile); "tag reason" -> count.
var lapsed := 0
var lapse_reasons := {}
## Diagnostic, casts plus orders: microseconds inside the game on behalf of the AI (AiSide subtracts them), delayed requests, and
## requests that took the real body or position of an unseen body (a guard: it stays 0).
var game_us: int:
	get: return _cast_us + (orders.game_us if orders != null else 0)
var delayed: int:
	get: return _cast_delayed + (orders.delayed if orders != null else 0)
var unseen_target_reads: int:
	get: return casts.unseen_target_reads + (orders.unseen_target_reads if orders != null else 0)
var orders_issued: int:
	get: return orders.orders_issued
var order_stats: Dictionary:
	get: return orders.order_stats

var _cast_us := 0
var _cast_delayed := 0
var _tick := 0
var _pending_cast := {}


func bind(side_slot: int, wizard_body: Node3D, orders_node: Node) -> void:
	slot = side_slot
	wizard = wizard_body
	orders.bind(side_slot, wizard, orders_node)
	var spawner := get_tree().get_first_node_in_group("unit_spawner")
	casts.bind(side_slot, wizard, spawner.get_node(spawner.spawn_path) if spawner != null else null)


## startCasting. Returns the answer of the Caster: the spell's name when it starts, or the reason it did not ("" = refused without a word).
func start_casting(spell: Resource, target: AiTrack, point: Vector3) -> String:
	if delay_ticks > 0:
		_pending_cast = {"spell": spell, "target": target, "point": point, "due": _tick + delay_ticks}
		## the cast is his newest decision: a walk of his still waiting would carry him off it
		if wizard != null:
			orders.forget(wizard.get_instance_id())
		_cast_delayed += 1
		return ""
	var began := Time.get_ticks_usec()
	var answer := casts.request(spell, target, point, audit, perception)
	_cast_us += Time.get_ticks_usec() - began
	## the casts and summons go to the same diagnostic table as the orders: «cast <tag>» -> [count, microseconds]
	orders.note("cast " + str(spell.get("tag")), Time.get_ticks_usec() - began)
	return answer


## Physics ticks the side has run (the clock of the delays and of the summon interval of the difficulty).
func now_tick() -> int:
	return _tick


## A cast decided and not yet asked (the delay of the difficulty): the wizard is busy until it leaves.
func cast_pending() -> bool:
	return not _pending_cast.is_empty()


## AiSide calls it at the start of every tick: the requests whose delay is over leave, the cast first, then the orders in the order
## they were decided.
func flush() -> void:
	_tick += 1
	orders.tick = _tick
	if delay_ticks <= 0:
		return
	if not _pending_cast.is_empty() and int(_pending_cast["due"]) <= _tick:
		var entry := _pending_cast
		_pending_cast = {}
		var target: AiTrack = entry["target"]
		var spell: Resource = entry["spell"]
		var track := perception.find(wizard) if perception != null else null
		var alive := target == null or AiWizardBrain.target_alive(target)
		var refusal := "" if track != null else "sin mago"
		if refusal.is_empty() and can_cast.is_valid():
			refusal = str(can_cast.call(track, spell, target, entry["point"]))
		## the target may have walked out of reach meanwhile (the Caster would answer «Fuera de alcance»)
		var reach := float(spell.get("cast_range_m")) if spell is SpellType else 0.0
		var aim_ok := target == null or can_aim(target)
		var in_reach := aim_ok and (target == null or not target.is_valid() or reach <= 0.0 \
				or wizard.global_position.distance_to(target.node.global_position) <= reach)
		if not alive:
			refusal = "blanco muerto"
		elif refusal.is_empty() and not in_reach:
			refusal = "fuera de alcance"
		if refusal.is_empty():
			var began := Time.get_ticks_usec()
			casts.request(spell, target, entry["point"], audit, perception)
			_cast_us += Time.get_ticks_usec() - began
		else:
			lapsed += 1
			var key := "%s %s" % [str(spell.get("tag")), refusal]
			lapse_reasons[key] = int(lapse_reasons.get(key, 0)) + 1
			if audit != null:
				audit.record("lapse", "slot %d %s" % [slot, key])
	orders.flush_due()


## A cast may take `target`: a body of another side only while the side sees it (the minimap is not a click).
func can_aim(target: AiTrack) -> bool:
	return aims(perception, target)


static func aims(side: AiPerception, target: AiTrack) -> bool:
	return side == null or side.knows_live(target)


## A body of another side the side does not see now.
static func unseen(side: AiPerception, target: AiTrack) -> bool:
	return target != null and side != null and target.is_valid() and not side.sees(target)
