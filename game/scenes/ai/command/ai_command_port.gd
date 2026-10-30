class_name AiCommandPort
extends Node

## The only way out of the AI into the game (RULES.md «IA»): a cast is the Caster call a human's
## click makes (request_cast, request_summon, request_structure), an order goes through the child
## `orders` (AiOrdersOut). So the AI pays mana and souls, waits for the cooldowns and cannot order
## what is not its own; it never touches a body, a pool or a purse. Only where the game is simulated
## (solo or the server): no RPC.
## With a delay (Easy, AiDifficulty.request_delay_s) every request waits `delay_ticks`, as a human's
## hand does; a waiting cast keeps the wizard busy and goes out only if it still can be paid and its
## target still lives (else it lapses, never a refusal). In no difficulty a request takes a body of
## another side the side does not see now: such a body is never clicked.

## What a brain asks a body to do (`ostate`). The numbers are the original's order states and show
## in the logs.
enum AiOrder {
	## No order given yet.
	NONE = 0,
	## Walk to within a radius of a point.
	MOVE_NEAR = 2,
	## Stay near a body (or a place) and fight what comes.
	GUARD = 3,
	## Walk to a point (the anchor of a record).
	MOVE = 4,
	## Stay by a body or a mana source (retreat, refill).
	REFILL = 5,
	## Attack a body.
	ATTACK = 6,
	## Advance to a point, fighting on the way.
	ADVANCE = 7,
	## The wizard walks onto a soul.
	TAKE_SOUL = 34,
}

@export var perception: AiPerception
## The orders of the AI (child `Orders`).
@export var orders: AiOrdersOut

var slot := 0
var wizard: WizardBody
## Physics ticks between a decision and its request (AiDifficulty.request_delay_s); 0 = at once.
var delay_ticks := 0:
	set(value):
		delay_ticks = value
		if orders != null:
			orders.delay_ticks = value
## The wizard brain's own test (lightCanCast and the rules of the rituals), checked again when a
## delayed cast leaves: (track, spell, target, point) -> "" or why not.
var can_cast: Callable
## Delayed casts that did not leave (they could no longer be paid or their target died meanwhile);
## "tag reason" -> count.
var lapsed := 0
var lapse_reasons := {}
## Diagnostic, casts plus orders: microseconds inside the game on behalf of the AI (AiSide subtracts
## them), delayed requests, and requests that took the real body or position of an unseen body (a
## guard: it stays 0).
var game_us: int:
	get:
		return _cast_us + (orders.game_us if orders != null else 0)
var delayed: int:
	get:
		return _cast_delayed + (orders.delayed if orders != null else 0)
var unseen_target_reads: int:
	get:
		var order_reads := orders.unseen_target_reads if orders != null else 0
		return _cast_unseen_reads + order_reads
var orders_issued: int:
	get:
		return orders.orders_issued
var order_stats: Dictionary:
	get:
		return orders.order_stats

var _caster: Caster
var _cast_us := 0
var _cast_delayed := 0
## Casts that took the real body of a body of another side the side did not see (a guard: no
## difficulty aims at one, it stays 0).
var _cast_unseen_reads := 0
var _tick := 0
var _pending_cast := {}
## What the Caster answered to the last request (its `feedback`).
var _answers: Array[String] = []


func bind(side_slot: int, wizard_body: Node3D, orders_node: Node) -> void:
	slot = side_slot
	wizard = wizard_body
	orders.bind(side_slot, wizard, orders_node)
	_caster = AiBody.caster(wizard)
	_caster.feedback.connect(_on_feedback)


## Returns the answer of the Caster: the spell's name when it starts, or the reason it
## did not ("" = refused without a word).
func start_casting(spell: Resource, target: AiTrack, point: Vector3) -> String:
	if delay_ticks > 0:
		_pending_cast = {
			"spell": spell, "target": target, "point": point, "due": _tick + delay_ticks
		}
		# the cast is his newest decision: a walk of his still waiting would carry him off it
		if wizard != null:
			orders.forget(wizard.get_instance_id())
		_cast_delayed += 1
		return ""
	var began := Time.get_ticks_usec()
	var answer := _request_cast(spell, target, point)
	_cast_us += Time.get_ticks_usec() - began
	# the casts and summons go to the same diagnostic table as the orders:
	# «cast <tag>» -> [count, microseconds]
	orders.note("cast " + str(spell.get("tag")), Time.get_ticks_usec() - began)
	return answer


## What the Caster would answer now to the click `start_casting` makes for this cast
## (Caster.action_status), without casting: "" when it would start. A summon has no click to ask
## about. Casting asks it before every cast.
func cast_status(spell: Resource, target: AiTrack, point: Vector3) -> String:
	if not (spell is SpellType):
		return ""
	var tag := (spell as SpellType).tag
	var node: Node3D = target.node if target != null and target.is_valid() else null
	if (spell as SpellType).is_structure and node == null:
		return _caster.action_status(tag, point, null)
	return _caster.action_status(tag, node.global_position if node != null else point, node)


## Physics ticks the side has run (the clock of the delays and of the summon interval of the
## difficulty).
func now_tick() -> int:
	return _tick


## A cast decided and not yet asked (the delay of the difficulty): the wizard is busy until it
## leaves.
func cast_pending() -> bool:
	return not _pending_cast.is_empty()


## AiSide calls it at the start of every tick: the requests whose delay is over leave, the cast
## first, then the orders in the order they were decided.
func flush() -> void:
	_tick += 1
	orders.tick = _tick
	if delay_ticks <= 0:
		return
	if not _pending_cast.is_empty() and int(_pending_cast["due"]) <= _tick:
		var entry := _pending_cast
		_pending_cast = {}
		_flush_cast(entry["spell"], entry["target"], entry["point"])
	orders.flush_due()


## A cast may take `target`: a body of another side only while the side sees it (the minimap is not
## a click).
func can_aim(target: AiTrack) -> bool:
	return aims(perception, target)


static func aims(side: AiPerception, target: AiTrack) -> bool:
	return side == null or side.knows_live(target)


## A body of another side the side does not see now.
static func unseen(side: AiPerception, target: AiTrack) -> bool:
	return target != null and side != null and target.is_valid() and not side.sees(target)


## A delayed cast whose time came: it leaves only if the wizard can still cast it on a live target
## within reach (the Caster would answer «Fuera de alcance»); else it lapses.
func _flush_cast(spell: Resource, target: AiTrack, point: Vector3) -> void:
	var track := perception.find(wizard) if perception != null else null
	var alive := target == null or AiWizardBrain.target_alive(target)
	var refusal := "" if track != null else "no wizard"
	if refusal.is_empty() and can_cast.is_valid():
		refusal = str(can_cast.call(track, spell, target, point))
	# the target may have walked out of reach meanwhile
	var reach := float(spell.get("cast_range_m")) if spell is SpellType else 0.0
	var in_reach := target == null or can_aim(target)
	if in_reach and target != null and target.is_valid() and reach > 0.0:
		in_reach = wizard.global_position.distance_to(target.node.global_position) <= reach
	if not alive:
		refusal = "target dead"
	elif refusal.is_empty() and not in_reach:
		refusal = "out of reach"
	if refusal.is_empty():
		var began := Time.get_ticks_usec()
		_request_cast(spell, target, point)
		_cast_us += Time.get_ticks_usec() - began
		return
	lapsed += 1
	var key := "%s %s" % [str(spell.get("tag")), refusal]
	lapse_reasons[key] = int(lapse_reasons.get(key, 0)) + 1


## The click: returns the answer of the Caster, the spell's name when it starts or the reason it did
## not ("" = refused without a word).
func _request_cast(spell: Resource, target: AiTrack, point: Vector3) -> String:
	_answers.clear()
	var tag := str(spell.get("tag"))
	var is_summon := spell is CreatureType
	if not is_summon and unseen(perception, target):
		if not aims(perception, target):
			return ""
		_cast_unseen_reads += 1
	var is_structure := spell is SpellType and (spell as SpellType).is_structure
	if is_summon:
		_caster.request_summon(tag)
	elif is_structure and target != null and target.is_valid():
		# Convert and Desecrate click a soul or a creature (the structures tab gives the spell, the
		# click the target): the same `request_cast` a human's click makes.
		_caster.request_cast(tag, target.node.global_position, target.node)
	elif is_structure:
		# a structure with no target (Manalith: the ground) goes by its entry of the tab
		_caster.request_structure(AiBody.spellbook(wizard).structure_index_of(tag), point)
	else:
		var node: Node3D = target.node if target != null and target.is_valid() else null
		_caster.request_cast(tag, node.global_position if node != null else point, node)
	return _answers[0] if not _answers.is_empty() else ""


func _on_feedback(text: String) -> void:
	_answers.append(text)
