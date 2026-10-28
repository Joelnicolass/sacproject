@tool
class_name RtsUnit
extends Node

## What makes a body a unit of the kit: drop one as a child of a Node3D or Node2D body (a
## CharacterBody3D, a CharacterBody2D, anything that stands somewhere). It says whose it is, what kind
## it is, whether it can be picked, ordered or targeted, how wide it is, and which orders it takes. It
## also holds the unit's order queue: the kit gives orders here (`give`), the game executes them
## (`order_started`) and reports back (`complete` / `fail`). It moves nothing and fights nothing.
##
## A game with its own rules (a pacifist that refuses attacks, a foe rule that is not "another team")
## extends this script and overrides `accepts`, `is_foe`, `facing_yaw` or `center_point`.
## Not: the selection (RtsSelection), who may order it (RtsOrders), how it walks (the game).

## The selection marked or unmarked it (a health bar shows only while selected, a ring under it…).
signal selected_changed(selected: bool)
## An order started: do it. `replaced` is the order it took over from (null when the unit was idle);
## `order.is_repeat_of(replaced)` tells a mere refresh.
signal order_started(order: RtsUnitOrder, replaced: RtsUnitOrder)
## An order left the unit: `result` is &"done" (complete), &"failed" (fail), &"replaced" (another order
## took its place), &"stopped" (stop) or &"cancelled" (dropped from the queue).
signal order_ended(order: RtsUnitOrder, result: StringName)
## An order waits in the queue behind the current one.
signal order_queued(order: RtsUnitOrder)

## Every unit in the tree.
const GROUP := &"rts_units"
const META := &"rts_unit"

## OWN: the local player's. ALLY: its team's. NEUTRAL: nobody's. ENEMY: a foe's.
const OWN := &"own"
const ALLY := &"ally"
const NEUTRAL := &"neutral"
const ENEMY := &"enemy"

## The side (player slot) that owns it; 0 = nobody (neutral).
@export var owner_slot := 1
## The team it fights for; -1 = its owner's slot (every player alone), 0 = neutral.
@export var team := -1
## What kind it is: "select every one of this kind" picks the same kind. A guard tied to a building can
## take the building's name as its kind, so its fellow guards go together.
@export var kind: StringName = &""
## Free tags the game filters by.
@export var tags: Array[StringName] = []
## Its owner may pick it (false while dead, while it summons…). Off also drops it from the selection
## and every group.
@export var selectable := true
## It takes orders now (false while dead, summoning, raging…).
@export var orderable := true
## Others may aim at it (false for a corpse, a stealthed unit…).
@export var targetable := true
## Its width in world units (meters in 3D, pixels in 2D): formations space units by the widest of the
## group.
@export var size := 1.0
## The point projected for a selection box (a Marker3D / Marker2D at the body's middle). Empty: the
## body's origin.
@export var center: Node
## The picture of the unit for a HUD.
@export var icon: Texture2D
## Command ids this unit never takes (a pacifist: [&"attack", &"attack_move"]).
@export var refused: Array[StringName] = []
## The formation it keeps (an id of the RtsOrders catalog); empty = the catalog's default.
@export var formation: StringName = &""

## The body this unit is (its parent).
var body: Node:
	get:
		return get_parent()
## Marked by the selection.
var selected := false:
	set(value):
		if value == selected:
			return
		selected = value
		selected_changed.emit(value)

var _current: RtsUnitOrder
var _queue: Array[RtsUnitOrder] = []


## The unit of `node`: the node itself, the body's unit, or the unit of the nearest ancestor that has
## one (a collider that is a child of the body). Null when there is none.
static func of(node: Object) -> RtsUnit:
	var at := node as Node
	for _depth in 4:
		if at == null or not is_instance_valid(at):
			return null
		if at is RtsUnit:
			return at as RtsUnit
		if at.has_meta(META):
			var unit: Variant = at.get_meta(META)
			if unit is RtsUnit and is_instance_valid(unit):
				return unit
		at = at.get_parent()
	return null


## Every unit in `tree`, in tree order.
static func all(tree: SceneTree) -> Array[RtsUnit]:
	var result: Array[RtsUnit] = []
	if tree == null:
		return result
	for node in tree.get_nodes_in_group(GROUP):
		if node is RtsUnit:
			result.append(node)
	return result


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	var parent := get_parent()
	if parent:
		parent.set_meta(META, self)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var parent := get_parent()
	if parent and parent.has_meta(META) and parent.get_meta(META) == self:
		parent.remove_meta(META)


func _get_configuration_warnings() -> PackedStringArray:
	var parent := get_parent()
	if parent != null and not (parent is Node3D or parent is Node2D):
		return PackedStringArray(["An RtsUnit goes under a Node3D or Node2D body."])
	return PackedStringArray()


## The team it fights for (its owner's slot when `team` is -1).
func team_id() -> int:
	return owner_slot if team < 0 else team


## True when it takes `command` (an RtsCommandType id). Override for a rule of the game.
func accepts(command: StringName) -> bool:
	return not refused.has(command)


## True when `other` is a foe: both are on a team (not neutral) and the teams differ. Override for a
## rule of the game (an alliance that changes, a neutral that bites).
func is_foe(other: RtsUnit) -> bool:
	if other == null or other == self:
		return false
	var mine := team_id()
	var theirs := other.team_id()
	return mine > 0 and theirs > 0 and mine != theirs


## What it is to the player of `slot` on team `local_team`: OWN, ALLY, NEUTRAL or ENEMY.
func relation_to(slot: int, local_team: int) -> StringName:
	if slot > 0 and owner_slot == slot:
		return OWN
	var theirs := team_id()
	if theirs <= 0:
		return NEUTRAL
	return ALLY if theirs == local_team else ENEMY


## True when the player of `slot` owns it.
func is_owned_by(slot: int) -> bool:
	return slot > 0 and owner_slot == slot


## Where it stands, as a kit point (RtsSpace).
func position() -> Vector3:
	return RtsSpace.position_of(body)


## The point a selection box projects: `center`, else the body's origin. Override to compute it.
func center_point() -> Vector3:
	if center != null and is_instance_valid(center):
		return RtsSpace.position_of(center)
	return position()


## The way it faces, as a kit yaw (a guard formation turns with it). Override for a body that faces
## another way than its basis (a model that looks at -Z).
func facing_yaw() -> float:
	return RtsSpace.yaw_of_node(body)


## True for a 2D body.
func is_2d() -> bool:
	return body is Node2D


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


# --- The order queue -------------------------------------------------------------------------------


## Gives an order. `queue` false: it replaces the current one and drops the queue. `queue` true: it
## waits behind the current one (it starts now when the unit is idle).
func give(order: RtsUnitOrder, queue := false) -> void:
	if order == null:
		return
	if queue and _current != null:
		order.queued = true
		_queue.append(order)
		order_queued.emit(order)
		return
	_drop_queue()
	var replaced := _current
	_current = order
	if replaced != null:
		order_ended.emit(replaced, &"replaced")
	order_started.emit(order, replaced)


## The game says the current order is done; the next queued one starts.
func complete() -> void:
	_finish(&"done")


## The game says the current order cannot be done (`reason` is free); the next queued one starts.
func fail(reason: StringName = &"failed") -> void:
	_finish(reason)


## Drops the current order and the queue: the unit is idle.
func stop() -> void:
	_drop_queue()
	var current := _current
	_current = null
	if current != null:
		order_ended.emit(current, &"stopped")


## The order being done, or null when idle.
func current_order() -> RtsUnitOrder:
	return _current


## The orders waiting, first to last (a copy).
func queued_orders() -> Array[RtsUnitOrder]:
	return _queue.duplicate()


func is_idle() -> bool:
	return _current == null


func _finish(result: StringName) -> void:
	var done := _current
	if done == null:
		return
	_current = null
	order_ended.emit(done, result)
	if _current == null and not _queue.is_empty():
		var next: RtsUnitOrder = _queue.pop_front()
		_current = next
		order_started.emit(next, null)


func _drop_queue() -> void:
	var dropped := _queue
	_queue = []
	for order in dropped:
		order_ended.emit(order, &"cancelled")
