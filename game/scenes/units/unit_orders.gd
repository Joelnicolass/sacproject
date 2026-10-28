@tool
extends Node

## The creature's current order and its AI.
## Runs where the body is simulated (server or solo) and drives UnitBody with
## begin_walk / engage / halt.
##
## MOVE walks to the spot and ignores enemies until it arrives, then the order ends.
## ATTACK chases its target at any range; when the target is gone the unit fights what it
## sees (patrol) or walks to where the target stood, then the order ends.
## GUARD follows a friendly body, GUARD_AREA holds a spot and RETREAT stays near the wizard:
## all three fight foes in sight of their anchor while within guard_range of it
## and never end on their own. ADVANCE fights foes in sight of
## its destination on the way and keeps that spot.

enum Command { NONE, MOVE, ATTACK, GUARD, GUARD_AREA, ADVANCE, RETREAT }

## How far (m) a guard stays from its anchor.
@export var guard_range := 50.0
## How far (m) a retreating body stays from the wizard, added to the wizard's radius.
@export var retreat_distance := 10.0
## MOVE stops inside this distance (0.5 m).
@export var arrive_distance := 0.5
@export var think_interval_s := 0.25
## The same order again (same command and target, GUARD / GUARD_AREA / ADVANCE): the unit takes the
## new point and thinks at its next physics tick (once), not at once and again on the next tick. The
## AI repeats the order of a follower each time its leader moves: each repeat cost two target
## searches, one inside the AI's tick. Off = every order thinks at once.
@export var defer_repeat_think := true
## The creature that owns this node (set in unit.tscn).
@export var body: UnitBody

var command: Command = Command.NONE
var target: Node3D
## Where the order points (ground spot, or where the target stood).
var point := Vector3.ZERO
## Formation slot (right, forward) in meters, turned by `facing`.
var offset := Vector2.ZERO
var facing := 0.0
## The formation this creature keeps; the group's next order uses the one most of its creatures
## have. Server only, not replicated.
var formation_id: StringName = &"line"

var _think_left := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	if body == null:
		return PackedStringArray(["Assign `body`: the UnitBody that owns this node."])
	return PackedStringArray()


func _ready() -> void:
	if not Engine.is_editor_hint() and body == null:
		push_error("%s: `body` is empty." % get_path())


func give(
	order_command: Command,
	order_target: Node3D,
	order_point: Vector3,
	order_offset: Vector2,
	order_facing: float
) -> void:
	if body.afflictions.raging():
		return
	if _is_repeat(order_command, order_target):
		point = order_point
		offset = order_offset
		facing = order_facing
		_think_left = 0.0
		return
	command = order_command
	target = order_target
	point = order_point
	offset = order_offset
	facing = order_facing
	_think_left = 0.0
	body.ordered = command != Command.NONE
	match command:
		Command.MOVE:
			body.walk_to(anchor())
		Command.ATTACK:
			body.engage(target)
		Command.NONE:
			body.halt()
		_:
			_think()


## A unit told again what it is doing: GUARD, GUARD_AREA or ADVANCE with the same target.
func _is_repeat(order_command: Command, order_target: Node3D) -> bool:
	if not defer_repeat_think or order_command != command or order_target != target:
		return false
	return command == Command.GUARD or command == Command.GUARD_AREA or command == Command.ADVANCE


func clear() -> void:
	command = Command.NONE
	target = null
	body.ordered = false


## Teleport: the creature loses its orders unless it is
## on guard or retreating. The body already stopped (warp_to), so a kept order thinks again at once.
func warped() -> void:
	if command == Command.GUARD or command == Command.RETREAT:
		_think_left = 0.0
		return
	clear()


## The spot this unit heads for: its formation slot around the target or the point.
func anchor() -> Vector3:
	var base := point
	var yaw := facing
	if command == Command.GUARD and _guardable(target):
		base = target.global_position
		yaw = _yaw_of(target)
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := ahead.cross(Vector3.UP)
	return base + right * offset.x + ahead * offset.y


func _physics_process(delta: float) -> void:
	if command == Command.NONE:
		return
	if body.is_dead():
		clear()
		return
	if body.afflictions.raging():
		clear()
		body.halt()
		return
	match command:
		Command.MOVE:
			if body.mode != UnitBody.Mode.MOVE:
				clear()
			return
		Command.ATTACK:
			if body.engagement.is_foe(target):
				if body.target != target:
					body.engage(target)
				return
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = think_interval_s
	_think()


func _think() -> void:
	match command:
		Command.ATTACK:
			_lost_target()
		Command.GUARD:
			if not _guardable(target):
				_lost_target()
				return
			point = target.global_position
			_hold(anchor(), guard_range, arrive_distance)
		Command.GUARD_AREA:
			_hold(anchor(), guard_range, arrive_distance)
		Command.ADVANCE:
			_hold(anchor(), INF, arrive_distance)
		Command.RETREAT:
			if not _guardable(target):
				clear()
				body.halt()
				return
			_hold(target.global_position, guard_range, _radius_of(target) + retreat_distance)


## An attack/guard order with a dead target: fight what is in sight, else walk to the last
## spot and drop the order (`goto case CommandType.move`).
func _lost_target() -> void:
	target = null
	var foe: Node3D = body.engagement.closest_foe(body.global_position)
	if foe:
		_engage(foe)
		return
	var spot := anchor()
	if _flat(body.global_position, spot) <= arrive_distance:
		clear()
		body.halt()
		return
	_walk(spot)


## Defend `center` while within `leash` of it. The picker is asked again
## every think; the current target weighs x1.3 there, so it is
## kept unless something better (or nothing: a futile target) comes up.
func _hold(center: Vector3, leash: float, stop_within: float) -> void:
	if _flat(body.global_position, center) <= leash:
		var foe: Node3D = _acquire(center, leash)
		if foe:
			_engage(foe)
			return
	if _flat(body.global_position, center) <= stop_within:
		if body.mode != UnitBody.Mode.IDLE:
			body.halt()
		return
	_walk(center)


## The target search of a guard (threshold min(100, distance to the anchor)*0.01) or,
## for ADVANCE (no leash), of an advance (reference 150, threshold 0.25). With a leash the
## foe must also be within the body's sight range of the anchor (at the anchor the threshold
## is ~0 and any foe the side has seen would be taken, then dropped as the threshold rises: jitter).
func _acquire(center: Vector3, leash: float) -> Node3D:
	if is_inf(leash):
		return body.engagement.closest_foe(center, 0.25, 150.0)
	var threshold := minf(100.0, _flat(body.global_position, center)) * 0.01
	var sight := body.vision.range_m()
	return body.engagement.closest_foe(center, threshold, 100.0, sight)


func _engage(foe: Node3D) -> void:
	var mode: int = body.mode
	if body.target == foe and (mode == UnitBody.Mode.CHASE or mode == UnitBody.Mode.ATTACK):
		return
	body.engage(foe)


func _walk(spot: Vector3) -> void:
	body.walk_to(spot)


## `node` is a Variant: an order's target may be freed while the order stands, and a freed object
## cannot be passed as a typed Node3D argument.
func _alive(node: Variant) -> bool:
	var live := _live(node)
	if live == null:
		return false
	if live is GameBody and (live as GameBody).is_dead():
		return false
	var health := live.get_node_or_null("Health") as Health
	return health == null or not health.is_dead()


## A dying
## wizard is dropped, a ghost (health 0 while it rises) is still guarded.
func _guardable(node: Variant) -> bool:
	var live := _live(node)
	if live == null:
		return false
	if live is WizardBody:
		return (live as WizardBody).is_guard_target()
	return _alive(live)


## `node` typed as a Node3D in the tree, or null if it is null, freed or out of the tree.
static func _live(node: Variant) -> Node3D:
	if node == null or not is_instance_valid(node) or not node is Node3D:
		return null
	var live := node as Node3D
	return live if live.is_inside_tree() else null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _yaw_of(node: Node3D) -> float:
	if node is GameBody:
		var ahead := (node as GameBody).facing_flat()
		return atan2(ahead.x, ahead.z)
	return node.rotation.y


static func _radius_of(node: Node3D) -> float:
	return BodyFacts.of_body(node).radius_m
