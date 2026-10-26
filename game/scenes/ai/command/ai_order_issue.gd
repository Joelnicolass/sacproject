class_name AiOrderIssue
extends RefCounted

## How an order of the AI reaches a body: why it is (or is not) a new order, and the call it becomes. A wizard walks
## (WizardBody.request_walk, the same as a click on the ground); a creature gets the command of its order state through
## Orders.apply_for, the same validation as a human's order. A body of another side the side does not see now is never taken:
## the creatures go where it was seen last. It does not decide nor delay orders (AiOrdersOut does). Static.
## Ref: shiny.d:2350-2391 issueOrder, 2393-2431 orderIfChanged.

const UnitOrders := preload("res://scenes/units/unit_orders.gd")
## orders.gd has no class_name (other scripts preload it).
const _ORDERS := preload("res://scenes/orders/orders.gd")
## Two positions are «the same order» within this squared distance. sacengine compares them exactly (shiny.d:2398); in the port a
## body rests with a jitter of centimeters (BodyAvoidance, the ground), so the exact test would re-issue the order of every
## follower every 12 ticks. 1 m² = 1 m («aprox.»).
const SAME_POS_SQ := 1.0


## Why `t` gets this order now, for the diagnostic table, or "" when it is the order it already has. «changed»: another ostate or
## target; «moved<3/<10/…»: the same order to a spot that moved (meters; «hold»: the body's own spot; «walking»/«still»: the body
## when it got it); «ended»: the same order again because the live one ended (sacengine re-issues it too).
static func reason(out: AiOrdersOut, t: AiTrack, ostate: int, target: AiTrack, pos: Variant) -> String:
	var why := "changed"
	if t.ord_state == ostate and (target == null or t.ord_target == target.id):
		if pos == null or t.ord_pos.distance_squared_to(pos as Vector3) <= SAME_POS_SQ:
			## completed orders are retained: fixed-position orders are not re-issued once the body has arrived (shiny.d:2400-2409)
			if (ostate == AiCommandPort.AiOrder.MOVE or ostate == AiCommandPort.AiOrder.ADVANCE) and t.cur_pos.distance_squared_to(t.ord_pos) <= 0.25:
				return ""
			if has_live_order(out, t):
				return ""
			why = "ended"
		else:
			var d := t.ord_pos.distance_to(pos as Vector3)
			why = "moved<3" if d < 3.0 else ("moved<10" if d < 10.0 else "moved")
			if (pos as Vector3) == t.cur_pos:
				why += " hold"
			if t.kind != AiTrack.Kind.WIZARD:
				why += " walking" if (t.node as UnitBody).is_walking() else " still"
	return why


## A unit with an order in progress, or a wizard walking (the live order sacengine compares with, shiny.d:2398).
static func has_live_order(out: AiOrdersOut, t: AiTrack) -> bool:
	if out.is_waiting(t.id):
		return true
	if t.kind == AiTrack.Kind.WIZARD:
		## still walking, or standing at the spot he was sent to (a retained, completed order)
		return (t.node as WizardBody).is_walking() or t.cur_pos.distance_squared_to(t.ord_pos) <= 4.0
	var orders_node := t.node.get_node_or_null("Orders")
	return orders_node != null and int(orders_node.get("command")) != UnitOrders.Command.NONE


## issueOrder in the commands of the port. Returns where the body was sent. A «retreat» of the original (GUARD and REFILL with a
## target: stay near it and fight) is `guard` here: Orders `retreat` orders every creature of the side to the wizard.
static func issue(out: AiOrdersOut, t: AiTrack, ostate: int, target: AiTrack, pos: Variant) -> Vector3:
	if t.kind == AiTrack.Kind.WIZARD:
		var goal: Vector3 = (pos as Vector3) if pos != null else (target.cur_pos if target != null else t.cur_pos)
		if pos == null and target != null and (ostate == AiCommandPort.AiOrder.GUARD or ostate == AiCommandPort.AiOrder.REFILL):
			var back := t.cur_pos - target.cur_pos
			back.y = 0.0
			## the wizard on guard stops this far from the body (AiTactics.wizard_stop_m; shiny.d:2376 `ntt+0x2e4 + 10.0`)
			var stop_m := out.play.tactics.wizard_stop_m
			if back.length() > stop_m:
				goal = target.cur_pos + back.normalized() * stop_m
			else:
				goal = t.cur_pos
		if out.audit != null:
			out.audit.record("order", "slot %d wizard walk %s" % [out.slot, AiAudit.fmt(goal)])
		out.wizard.request_walk(goal)
		out.orders_issued += 1
		return goal
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
	## The game refuses «advance» and «attack» to a pacifist (Orders._own_units, sacengine order()): the original AI keeps asking
	## and is refused every time; the port does not call, so the Manahoars wait where they were summoned.
	var type: Variant = t.node.get("type")
	if (ostate == AiCommandPort.AiOrder.ATTACK or ostate == AiCommandPort.AiOrder.ADVANCE) and type != null and (type as CreatureType).aggressiveness <= 0:
		return t.cur_pos
	var goal_node: Node3D = target.node if target != null and target.is_valid() else null
	var seen_at := t.cur_pos
	if goal_node != null and AiCommandPort.unseen(out.perception, target):
		if AiCommandPort.aims(out.perception, target):
			out.unseen_target_reads += 1
		else:
			## a body the side does not see: its creatures go to where it was seen last (024e, no perfect information)
			seen_at = target.cur_pos
			goal_node = null
			## guard it -> hold that place; attack it -> advance there (fight what is found on the way)
			if command == "guard":
				command = "guard_area"
			elif command == "attack":
				command = "advance"
	var point: Vector3 = (pos as Vector3) if pos != null else (goal_node.global_position if goal_node != null else seen_at)
	if out.audit != null:
		out.audit.record("order", "slot %d %s %s %s" % [out.slot, t.node.name, command, AiAudit.fmt(point)])
	out.orders_issued += 1
	(out.world_orders as _ORDERS).apply_for(out.slot, [t.node], command, point, goal_node)
	return point
