class_name Engagement
extends Node

## Whom a creature is committed to: its `target`, and the commands that begin or end a commitment (engage a foe, walk somewhere, stand
## still, cower, follow a leader). It asks the TargetPicker who is worth fighting and keeps the Vision of the body on only while it can look.
## Not: how to hit (Weapons), what each mode does (States) nor the orders of the player (UnitOrders).

const _ORDERS := preload("res://scenes/units/unit_orders.gd")

@export var body: UnitBody
@export var afflictions: Afflictions
@export var orders: _ORDERS
## Without it the closest foe in sight is the pick, and anything of another side is a valid target.
@export var picker: TargetPicker
## Announces a jump to the clients (empty = the body glides).
@export var warp_snap: WarpSnap

## The body it fights or walks toward now.
var target: Node3D


func _ready() -> void:
	if body.rules != null:
		body.vision.rules = body.rules
	body.mode_changed.connect(_sync_vision.unbind(2))
	_sync_vision()
	afflictions.held_changed.connect(cancel_attacks.unbind(1))


## Server or solo: goes for `foe` (a chase, unless it is already hitting).
func engage(foe: Node3D) -> void:
	if not _free() or not accepts_target(foe):
		return
	if target != foe:
		cancel_attacks()
		target = foe
	if body.mode != UnitBody.Mode.ATTACK and body.mode != UnitBody.Mode.SHOOT:
		body.mode = UnitBody.Mode.CHASE


## Walks straight to `goal` (the Move state steers there); an order-level walk is `walk_to`.
func walk(goal: Vector3) -> void:
	if _free():
		body.locomotion.goal = goal
		drop()
		body.mode = UnitBody.Mode.MOVE


## An order-level walk: by the waypoints of the PathFollower child, or straight when the body has none or goes by air.
func walk_to(point: Vector3) -> void:
	if not _free():
		return
	if body.air.flies_to(point) or not is_instance_valid(body.path_follower):
		walk(point)
	else:
		body.path_follower.go_to(point)


func halt() -> void:
	if _free():
		drop()
		body.mode = UnitBody.Mode.IDLE


## Stops where it is and crouches until something else moves it.
func cower() -> void:
	if _free() and body.mode != UnitBody.Mode.COWER:
		drop()
		body.mode = UnitBody.Mode.COWER


## Charm: it forgets its orders and its target and is told to follow `leader` (its new wizard).
func follow(leader: Node3D) -> void:
	orders.clear()
	halt()
	orders.give(_ORDERS.Command.RETREAT, leader, leader.global_position, Vector2.ZERO, 0.0)


## Teleport: the body is at `point` (a spot on the land) in one step, at the height it had over the ground if it flies, with no goal,
## target or velocity; it keeps its order only if it is guard or retreat.
func warp(point: Vector3) -> void:
	var above := maxf(0.0, body.global_position.y - body.air.ground_height(body.global_position)) if body.is_flying() else 0.0
	body.global_position = Vector3(point.x, point.y + above, point.z)
	body.velocity = Vector3.ZERO
	halt()
	if orders != null:
		orders.warped()
	if warp_snap != null:
		warp_snap.announce()


## Forgets the target and stops hitting.
func drop() -> void:
	target = null
	cancel_attacks()


func cancel_attacks() -> void:
	if body.mode == UnitBody.Mode.ROCK_FORM and body.simulates() and afflictions.breaks_special_modes():
		body.mode = UnitBody.Mode.IDLE  # Petrified ends Rockform; Afflictions.held_changed calls here.
	body.weapons.cancel_all()
	body.clips.cancel_lunge()


## The visible foe of the best score above `threshold` around `center` (idle 0.25; guard min(100, d)*0.01; advance 0.25 with ref
## 150), or the closest foe within sight without a picker. Null for a pacifist (aggressiveness 0).
func closest_foe(center: Vector3, threshold := 0.25, ref_range := 100.0, within := INF) -> Node3D:
	var type := body.type
	if type == null or (type.aggressiveness <= 0 and not afflictions.raging()):
		return null
	if is_instance_valid(picker):
		return picker.pick(center, threshold, ref_range, within)
	return TargetRules.closest_in_sight(body, center)


## Whether it may keep `node` as its target, by its TargetPolicy; without one, the target of an explicit ATTACK order is any body not of
## the own side and anything else a stance enemy.
func accepts_target(node: Variant) -> bool:
	var explicit := is_attack_order_on(node)
	return picker.accepts(node, explicit) if is_instance_valid(picker) else TargetRules.is_valid_foe_of(body.owner_slot, node, body, not explicit)


## A foe by the rules of orders (Orders retarget); by stance, except the target of an explicit ATTACK order.
func is_foe(node: Variant) -> bool:
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not is_attack_order_on(node))


## `node` is the target of its explicit ATTACK order (a click, the AI's port): the one body it fights without asking the stance.
func is_attack_order_on(node: Variant) -> bool:
	if not body.ordered or node == null or not is_instance_valid(node):
		return false
	if not is_instance_valid(orders) or orders.command != _ORDERS.Command.ATTACK or not is_instance_valid(orders.target):
		return false
	return orders.target == node


## The picker's TargetFutility banned `node` (it would not lose health). False without a picker.
func is_futile(node: Variant) -> bool:
	return is_instance_valid(picker) and picker.is_banned(node)


## Not dead, not being summoned and not held by a Sac Doctor: it takes commands.
func _free() -> bool:
	return body.mode != UnitBody.Mode.DEAD and body.mode != UnitBody.Mode.SUMMONING and not body.is_taken()


## A body looks only while it simulates and is alive, summoned and free: not as a corpse, a summon in the making or a held creature.
func _sync_vision() -> void:
	body.vision.watching = body.simulates() and _free()
