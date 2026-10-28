@tool
class_name AiOrdersOut
extends Node

## The orders the AI gives its bodies. An order is issued only when it changes; the radius variants
## hold a position when the body is already close. With a delay (Easy) an order waits `delay_ticks`,
## and a newer decision for the same body replaces it and keeps its time. An order becomes the call
## a human's order makes: a wizard walks (WizardBody.request_walk, a click on the ground); a
## creature gets the command of its order state through Orders.apply_for, the same validation as a
## human's order. A body of another side the side does not see now is never taken: the creatures go
## where it was seen last. It does not cast (the port does) and it never touches a body. Child
## `Orders` of the port, which binds it and gives it its clock.

const UnitOrders := preload("res://scenes/units/unit_orders.gd")
## orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/orders/orders.gd")
## Two positions are «the same order» within this squared distance. The engine compares them
## exactly; in the port a body rests with a jitter of centimeters (BodyAvoidance, the ground), so
## the exact test would re-issue the order of every follower every 12 ticks. 1 m² = 1 m («aprox.»).
const SAME_POS_SQ := 1.0
## A body this close (squared meters) to the spot of its MOVE or ADVANCE has completed it: the order
## is retained and not issued again.
const ARRIVED_SQ := 0.25
## A wizard standing this close (squared meters) to the spot he was sent to still holds that order.
const WIZARD_AT_GOAL_SQ := 4.0
## Diagnostic: how far the spot of a re-issued order moved, in meters.
const MOVED_NEAR_M := 3.0
const MOVED_FAR_M := 10.0

@export var perception: AiPerception

## What the side plays with (AiSide.setup): the wizard's stop distance on guard.
var play: AiPlay
## Set by the port: the side, its wizard and the world's Orders (bind), the delay and the tick
## (flush).
var slot := 0
var wizard: WizardBody
var world_orders: Node
var delay_ticks := 0
var tick := 0
var orders_issued := 0
## Diagnostic for the report: the issued orders (and the port's casts) by «kind ostate reason» ->
## [count, microseconds] (`_reason` says what the reasons mean).
var order_stats := {}
## The port adds these to its own (game_us: microseconds inside the game; unseen_target_reads: a
## guard that stays 0).
var game_us := 0
var delayed := 0
var unseen_target_reads := 0
## track id -> {t, ostate, target, pos, due}: one waiting order per body, the newest decision.
var _pending_orders := {}


func _get_configuration_warnings() -> PackedStringArray:
	if perception:
		return PackedStringArray()
	return PackedStringArray(["Missing the `perception` socket."])


func bind(side_slot: int, wizard_body: WizardBody, orders_node: Node) -> void:
	slot = side_slot
	wizard = wizard_body
	world_orders = orders_node


## Whether the body has an order waiting its delay.
func is_waiting(id: int) -> bool:
	return _pending_orders.has(id)


## The body's waiting order is dropped (the port: a cast is the wizard's newest decision).
func forget(id: int) -> void:
	_pending_orders.erase(id)


## The waiting orders whose delay is over leave, in the order they were decided (the port calls it
## after its cast).
func flush_due() -> void:
	if _pending_orders.is_empty():
		return
	var due: Array = []
	for id in _pending_orders:
		if int(_pending_orders[id]["due"]) <= tick:
			due.append(id)
	for id in due:
		var entry: Dictionary = _pending_orders[id]
		_pending_orders.erase(id)
		var t: AiTrack = entry["t"]
		if not t.is_valid():
			continue
		var began := Time.get_ticks_usec()
		var goal := _issue(t, entry["ostate"], entry["target"], entry["pos"])
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		note(str(entry["key"]), spent)
		t.ord_pos = goal


## `target` is a track or null; `pos` a Vector3 or null.
func order_if_changed(
	t: AiTrack, ostate: AiCommandPort.AiOrder, target: AiTrack, pos: Variant
) -> void:
	if t.kind == AiTrack.Kind.STRUCTURE or not t.is_valid():
		return
	var reason := _reason(t, ostate, target, pos)
	if reason.is_empty():
		return
	var key := "%s %d %s" % [AiTrack.Kind.keys()[t.kind], ostate, reason]
	var at := t.cur_pos
	if pos != null:
		at = pos as Vector3
	elif target != null:
		at = target.cur_pos
	if DebugLog.on(&"ai_order"): print(
			(
				"ai_order tick %d slot %d %s ost %d->%d %s goal %.1f,%.1f,%.1f"
				% [tick, slot, t.node.name, t.ord_state, ostate, reason, at.x, at.y, at.z]
			)
		)
	var goal: Vector3
	if delay_ticks > 0:
		# The order waits its delay; a newer decision for the same body replaces it and keeps its
		# time (else a body whose anchor moves would never get one).
		var waiting: Dictionary = _pending_orders.get(t.id, {})
		_pending_orders[t.id] = {
			"t": t,
			"ostate": ostate,
			"target": target,
			"pos": pos,
			"key": key,
			"due": int(waiting.get("due", tick + delay_ticks)),
		}
		delayed += 1
		goal = at
	else:
		var began := Time.get_ticks_usec()
		goal = _issue(t, ostate, target, pos)
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		note(key, spent)
	t.ord_state = ostate
	if t.kind == AiTrack.Kind.WIZARD and ostate == AiCommandPort.AiOrder.ATTACK:
		t.ord_state = AiCommandPort.AiOrder.ADVANCE
	t.ord_target = target.id if target != null else 0
	t.ord_pos = goal


## Inside `radius` of the target the body holds where it stands. Returns true
## when it is that close.
func order_target_radius(
	t: AiTrack, ostate: AiCommandPort.AiOrder, target: AiTrack, radius: float
) -> bool:
	if radius > 0.0 and not (radius * radius < t.cur_pos.distance_squared_to(target.cur_pos)):
		order_if_changed(t, ostate, null, t.cur_pos)
		return true
	order_if_changed(t, ostate, target, null)
	return false


## Farther than `radius` from `pos` the body goes there, else it holds where it
## stands. Returns true when it is that close.
func order_pos_radius(
	t: AiTrack, ostate: AiCommandPort.AiOrder, pos: Vector3, radius: float
) -> bool:
	if radius * radius < t.cur_pos.distance_squared_to(pos):
		order_if_changed(t, ostate, null, pos)
		return false
	order_if_changed(t, ostate, null, t.cur_pos)
	return true


## Too far from `anchor` (more than `radius`): go there (MOVE). Near: at a structure
## stay by it and fight what comes (REFILL), at an enemy Manalith attack it (ATTACK; ADVANCE with
## more than one guardian, which the port does not count), else advance to the anchor (ADVANCE).
## Returns true when it is near.
func order_interact(t: AiTrack, anchor: Vector3, target: AiTrack, radius: float) -> bool:
	if radius * radius < t.cur_pos.distance_squared_to(anchor):
		order_if_changed(t, AiCommandPort.AiOrder.MOVE, null, anchor)
		return false
	if target != null and target.kind == AiTrack.Kind.STRUCTURE:
		if target.site == AiTrack.Site.MANALITH:
			order_if_changed(t, AiCommandPort.AiOrder.ATTACK, target, anchor)
		else:
			order_if_changed(t, AiCommandPort.AiOrder.REFILL, target, null)
	else:
		order_if_changed(t, AiCommandPort.AiOrder.ADVANCE, null, anchor)
	return true


## A walk to a place (the wizard going to a soul, AiOrder.TAKE_SOUL: the original's «brain-driven
## engage», a move here).
func order_go_to(t: AiTrack, ostate: AiCommandPort.AiOrder, pos: Vector3) -> void:
	order_if_changed(t, ostate, null, pos)


func note(key: String, spent_us: int) -> void:
	var row: Array = order_stats.get(key, [0, 0])
	row[0] += 1
	row[1] += spent_us
	order_stats[key] = row


## Why `t` gets this order now, for the diagnostic table, or "" when it is the order it already has.
## «changed»: another ostate or target; «moved<3/<10/…»: the same order to a spot that moved
## (meters; «hold»: the body's own spot; «walking»/«still»: the body when it got it); «ended»: the
## same order again because the live one ended.
func _reason(t: AiTrack, ostate: AiCommandPort.AiOrder, target: AiTrack, pos: Variant) -> String:
	if t.ord_state != ostate or (target != null and t.ord_target != target.id):
		return "changed"
	if pos == null or t.ord_pos.distance_squared_to(pos as Vector3) <= SAME_POS_SQ:
		# completed orders are retained: fixed-position orders are not re-issued once the body has
		# arrived
		var fixed := ostate == AiCommandPort.AiOrder.MOVE or ostate == AiCommandPort.AiOrder.ADVANCE
		if fixed and t.cur_pos.distance_squared_to(t.ord_pos) <= ARRIVED_SQ:
			return ""
		if _has_live_order(t):
			return ""
		return "ended"
	var d := t.ord_pos.distance_to(pos as Vector3)
	var why := "moved"
	if d < MOVED_NEAR_M:
		why = "moved<3"
	elif d < MOVED_FAR_M:
		why = "moved<10"
	if (pos as Vector3) == t.cur_pos:
		why += " hold"
	if t.kind != AiTrack.Kind.WIZARD:
		why += " walking" if (t.node as UnitBody).is_walking() else " still"
	return why


## A unit with an order in progress, or a wizard walking.
func _has_live_order(t: AiTrack) -> bool:
	if is_waiting(t.id):
		return true
	if t.kind == AiTrack.Kind.WIZARD:
		# still walking, or standing at the spot he was sent to (a retained, completed order)
		var walking := (t.node as WizardBody).is_walking()
		return walking or t.cur_pos.distance_squared_to(t.ord_pos) <= WIZARD_AT_GOAL_SQ
	var orders_node := t.node.get_node_or_null("Orders")
	return orders_node != null and int(orders_node.get("command")) != UnitOrders.Command.NONE


## The call the order becomes. Returns where the body was sent. A «retreat» of the
## original (GUARD and REFILL with a target: stay near it and fight) is `guard` here: Orders
## `retreat` orders every creature of the side to the wizard.
func _issue(t: AiTrack, ostate: AiCommandPort.AiOrder, target: AiTrack, pos: Variant) -> Vector3:
	if t.kind == AiTrack.Kind.WIZARD:
		return _walk_wizard(t, ostate, target, pos)
	var command := ""
	match ostate:
		AiCommandPort.AiOrder.MOVE_NEAR, AiCommandPort.AiOrder.MOVE:
			command = "move"
		AiCommandPort.AiOrder.GUARD:
			command = "guard" if target != null else "guard_area"
		AiCommandPort.AiOrder.REFILL:
			command = "guard" if target != null else "move"
		AiCommandPort.AiOrder.ATTACK:
			command = "attack"
		AiCommandPort.AiOrder.ADVANCE:
			command = "advance"
		AiCommandPort.AiOrder.TAKE_SOUL:
			command = "guard" if target != null else "guard_area"
		_:
			return t.cur_pos
	# The game refuses «advance» and «attack» to a pacifist (Orders._own_units): the original AI
	# keeps asking and is refused every time; the port does not call, so the Manahoars wait where
	# they were summoned.
	var type: Variant = t.node.get("type")
	var fight := ostate == AiCommandPort.AiOrder.ATTACK or ostate == AiCommandPort.AiOrder.ADVANCE
	if fight and type != null and (type as CreatureType).aggressiveness <= 0:
		return t.cur_pos
	var goal_node: Node3D = target.node if target != null and target.is_valid() else null
	var seen_at := t.cur_pos
	if goal_node != null and AiCommandPort.unseen(perception, target):
		if AiCommandPort.aims(perception, target):
			unseen_target_reads += 1
		else:
			# a body the side does not see: its creatures go to where the side believes it is
			# (last seen, or on the minimap)
			seen_at = perception.pos_of(target)
			goal_node = null
			# guard it -> hold that place; attack it -> advance there (fight what is found on the
			# way)
			if command == "guard":
				command = "guard_area"
			elif command == "attack":
				command = "advance"
	var point := seen_at
	if pos != null:
		point = pos as Vector3
	elif goal_node != null:
		point = goal_node.global_position
	orders_issued += 1
	(world_orders as _ORDERS).apply_for(slot, [t.node], command, point, goal_node)
	return point


## The wizard walks: to `pos`, else to the target, else he stays. On GUARD or REFILL of a target he
## stops `wizard_stop_m` from it.
func _walk_wizard(
	t: AiTrack, ostate: AiCommandPort.AiOrder, target: AiTrack, pos: Variant
) -> Vector3:
	var goal := t.cur_pos
	if pos != null:
		goal = pos as Vector3
	elif target != null:
		goal = target.cur_pos
	var stays_by := ostate == AiCommandPort.AiOrder.GUARD or ostate == AiCommandPort.AiOrder.REFILL
	if pos == null and target != null and stays_by:
		var back := t.cur_pos - target.cur_pos
		back.y = 0.0
		var stop_m := play.tactics.wizard_stop_m
		if back.length() > stop_m:
			goal = target.cur_pos + back.normalized() * stop_m
		else:
			goal = t.cur_pos
	wizard.request_walk(goal)
	orders_issued += 1
	return goal
