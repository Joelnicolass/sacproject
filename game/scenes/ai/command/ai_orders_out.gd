@tool
class_name AiOrdersOut
extends Node

## The orders the AI gives its bodies. An order is issued only when it changes; the radius variants hold a position when the body
## is already close. With a delay (Easy) an order waits `delay_ticks`, and a newer decision for the same body replaces it and keeps
## its time. AiOrderIssue turns it into the call a human's order makes. It does not cast (the port does) and it never touches a
## body. Child `Orders` of the port, which binds it and gives it its clock. Ref: shiny.d:2393-2478.

@export var perception: AiPerception
## What the side plays with (AiSide.setup): the wizard's stop distance on guard.
var play: AiPlay

## Set by the port: the side, its wizard and the world's Orders (bind), the audit, the delay and the tick (flush).
var audit: AiAudit
var slot := 0
var wizard: WizardBody
var world_orders: Node
var delay_ticks := 0
var tick := 0
var orders_issued := 0
## Diagnostic for the report: the issued orders (and the port's casts) by «kind ostate reason» -> [count, microseconds]
## (AiOrderIssue.reason says what the reasons mean).
var order_stats := {}
## The port adds these to its own (game_us: microseconds inside the game; unseen_target_reads: perfect information only).
var game_us := 0
var delayed := 0
var unseen_target_reads := 0
## track id -> {t, ostate, target, pos, due}: one waiting order per body, the newest decision.
var _pending_orders := {}


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if perception else PackedStringArray(["Falta el socket `perception`."])


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


## The waiting orders whose delay is over leave, in the order they were decided (the port calls it after its cast).
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
		var goal := AiOrderIssue.issue(self, t, int(entry["ostate"]), entry["target"], entry["pos"])
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		note(str(entry["key"]), spent)
		t.ord_pos = goal


## orderIfChanged. `target` is a track or null; `pos` a Vector3 or null.
func order_if_changed(t: AiTrack, ostate: int, target: AiTrack, pos: Variant) -> void:
	if t.kind == AiTrack.Kind.STRUCTURE or not t.is_valid():
		return
	var reason := AiOrderIssue.reason(self, t, ostate, target, pos)
	if reason.is_empty():
		return
	var key := "%s %d %s" % [AiTrack.Kind.keys()[t.kind], ostate, reason]
	if DebugLog.on(&"ai_order"):
		print("ai_order tick %d slot %d %s ost %d->%d %s goal %s" % [tick, slot, t.node.name, t.ord_state, ostate, reason,
			AiAudit.fmt((pos as Vector3) if pos != null else (target.cur_pos if target != null else t.cur_pos))])
	var goal: Vector3
	if delay_ticks > 0:
		## The order waits its delay; a newer decision for the same body replaces it and keeps its time (else a body whose anchor
		## moves would never get one).
		var waiting: Dictionary = _pending_orders.get(t.id, {})
		_pending_orders[t.id] = {"t": t, "ostate": ostate, "target": target, "pos": pos, "key": key, "due": int(waiting.get("due", tick + delay_ticks))}
		delayed += 1
		goal = (pos as Vector3) if pos != null else (target.cur_pos if target != null else t.cur_pos)
	else:
		var began := Time.get_ticks_usec()
		goal = AiOrderIssue.issue(self, t, ostate, target, pos)
		var spent := Time.get_ticks_usec() - began
		game_us += spent
		note(key, spent)
	t.ord_state = AiCommandPort.AiOrder.ADVANCE if (t.kind == AiTrack.Kind.WIZARD and ostate == AiCommandPort.AiOrder.ATTACK) else ostate
	t.ord_target = target.id if target != null else 0
	t.ord_pos = goal


## orderTargetRadius (shiny.d:2433-2445): inside `radius` of the target the body holds where it stands.
func order_target_radius(t: AiTrack, ostate: int, target: AiTrack, radius: float) -> int:
	if radius > 0.0 and not (radius * radius < t.cur_pos.distance_squared_to(target.cur_pos)):
		order_if_changed(t, ostate, null, t.cur_pos)
		return 1
	order_if_changed(t, ostate, target, null)
	return 0


## orderPosRadius (shiny.d:2441-2452).
func order_pos_radius(t: AiTrack, ostate: int, pos: Vector3, radius: float) -> int:
	if radius * radius < t.cur_pos.distance_squared_to(pos):
		order_if_changed(t, ostate, null, pos)
		return 0
	order_if_changed(t, ostate, null, t.cur_pos)
	return 1


## orderInteract (shiny.d:2452-2478, 0x487550): too far from `anchor` (more than `radius`): go there (MOVE). Near: at a structure
## stay by it and fight what comes (REFILL), at an enemy Manalith attack it (ATTACK; ADVANCE with more than one guardian, which the
## port does not count), else advance to the anchor (ADVANCE). Returns 1 when it is near.
func order_interact(t: AiTrack, anchor: Vector3, target: AiTrack, radius: float) -> int:
	if radius * radius < t.cur_pos.distance_squared_to(anchor):
		order_if_changed(t, AiCommandPort.AiOrder.MOVE, null, anchor)
		return 0
	if target != null and target.kind == AiTrack.Kind.STRUCTURE:
		if target.site == AiTrack.Site.MANALITH:
			order_if_changed(t, AiCommandPort.AiOrder.ATTACK, target, anchor)
		else:
			order_if_changed(t, AiCommandPort.AiOrder.REFILL, target, null)
	else:
		order_if_changed(t, AiCommandPort.AiOrder.ADVANCE, null, anchor)
	return 1


## A walk to a place (the wizard going to a soul, AiOrder.TAKE_SOUL: the original's «brain-driven engage», a move here).
func order_go_to(t: AiTrack, ostate: int, pos: Vector3) -> void:
	order_if_changed(t, ostate, null, pos)


func note(key: String, spent_us: int) -> void:
	var row: Array = order_stats.get(key, [0, 0])
	row[0] += 1
	row[1] += spent_us
	order_stats[key] = row
