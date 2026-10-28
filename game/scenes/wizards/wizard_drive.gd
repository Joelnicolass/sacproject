@tool
class_name WizardDrive
extends Node

## The one writer of a wizard's movement each tick. `step` is what `WizardBody.mp_move` runs: the kit runs it on the server for every
## frame of the owner's keys, on the owner at once with its own keys and again when it reconciles, and an AI seat or a test-scene body
## runs it with no keys at all. A step reads only what travels in the MpSync (the pose, `velocity`, `speed_factor`, `locked`) and the
## keys, so the server, the owner and a replay get the same answer; the walk orders (`walking`, `goal`) are the server's alone.
## Owns `locked`: the server derives it every step from what holds the wizard (a stun or a tumble, a structure cast, a ghost that
## cannot move, the seating), and the owner reads the copy that arrived, because `Caster.holds_wizard` is not true on a client.
## Not: where the keys come from (`WizardBody` sets the values `forward` and `yaw` of its MpInput), the slide and the fall
## (Locomotion), the pose of a client (MpActor), nor what a fall means (the body).

## The keys' `forward` and `yaw` are the only inputs; anything else a peer sends is dropped by `_forward_of` and `_yaw_of`.
@export var body: WizardBody
@export var locomotion: Locomotion
@export var afflictions: Afflictions
@export var caster: Caster
@export var ghost: GhostForm
## The path of an order-level walk (go_to); `cancel_orders` stops it.
@export var follower: PathFollower

## Held, ghost that cannot move or seating: it neither walks nor turns. Server writes, clients read (MpSync).
var locked := false
## A walk order is on (server only): `goal` is its leg.
var walking := false
var goal := Vector3.ZERO
## The last step set a flat velocity (the wizard was walking, by keys or by order). Server only: regeneration reads it.
var moving := false


func _get_configuration_warnings() -> PackedStringArray:
	if body == null or locomotion == null or afflictions == null or caster == null or ghost == null:
		return PackedStringArray(["Assign body, locomotion, afflictions, caster and ghost."])
	return PackedStringArray()


## One tick of movement. `keys` carries `forward` (-1..1) and `yaw`; null = no player (an AI seat, a walk order only).
func step(keys: MpInput, delta: float) -> void:
	var authority := is_multiplayer_authority()
	var held := false
	if authority:
		if body.is_seating():
			locked = true
			return
		held = afflictions.holds() or caster.holds_wizard()
		locked = held or not ghost.can_move()
		# A held wizard keeps its order and waits; one that cannot move at all forgets it.
		walking = walking and (held or not locked)
	locomotion.begin(delta)
	var forward := 0.0
	var yaw := body.rotation.y
	if not locked and keys != null:
		forward = _forward_of(keys)
		yaw = _yaw_of(keys, yaw)
	body.rotation.y = yaw
	var pace := pace_m_s()
	moving = false
	if absf(forward) > 0.001 and pace > 0.0:
		walking = false
		var ahead := body.facing_flat()
		body.velocity.x = ahead.x * pace * forward
		body.velocity.z = ahead.z * pace * forward
		moving = true
	elif walking and pace > 0.0 and not held:
		_walk_leg(pace, delta)
	else:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	locomotion.finish_now(delta, body.is_obstacle)


## Meters per second at full stride: the type's run speed (or the walk cycle's), times the speed factors.
func pace_m_s() -> float:
	var base := body.move_speed
	if base <= 0.0 and body.step != null:
		base = body.step.speed()
	return base * body.speed_factor * ghost.speed_factor()


## Server: a straight leg of a walk order (what the PathFollower hands out). It ends within one step of `point`.
func begin_walk(point: Vector3) -> void:
	goal = point
	if walking:
		return
	walking = true
	body.walk_changed.emit(true)


func stop_walk() -> void:
	if not walking:
		return
	walking = false
	body.walk_changed.emit(false)


## The player's link dropped, or the body was moved: no order goes on without him.
func cancel_orders() -> void:
	if follower != null:
		follower.cancel()
	stop_walk()


func _walk_leg(pace: float, delta: float) -> void:
	var flat := Vector3(goal.x - body.global_position.x, 0.0, goal.z - body.global_position.z)
	if flat.length() <= pace * delta:
		walking = false
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		body.walk_changed.emit(false)
		return
	var direction := flat.normalized()
	body.velocity.x = direction.x * pace
	body.velocity.z = direction.z * pace
	moving = true


## A peer sends anything: only a finite number counts, and the stride is clamped to -1..1.
func _forward_of(keys: MpInput) -> float:
	var raw: Variant = keys.get_value(&"forward", 0.0)
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return 0.0
	var value := float(raw)
	return clampf(value, -1.0, 1.0) if is_finite(value) else 0.0


## The heading the player looks at; without a finite one the wizard keeps his.
func _yaw_of(keys: MpInput, current: float) -> float:
	var raw: Variant = keys.get_value(&"yaw")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return current
	var value := float(raw)
	return value if is_finite(value) else current
