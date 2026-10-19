class_name Pushback
extends Node

## F121 (RFC-030j): Squall's push, sacengine Pushback (state.d:4768-4776, updatePushback 24017-24031). A child of the
## body it pushes (it goes with the body), server (or solo) only. For `duration_ticks` ticks it pushes the body at
## `speed` m/s along the shot (BodyNudge.push: it slides on the land, a step off the land is not taken). A thrown body
## (Tumbling on) gets the velocity once and the push ends. Effects run before the creatures (state.d:29331): the
## node's physics priority is −1, so it pushes before the body moves.

## sacengine pushDistance / pushDuration = 15 m in 2/3 s.
@export var speed := 22.5
@export var duration_ticks := 40

var direction := Vector3.ZERO
var _done := 0
var _moved := 0.0
var _from := Vector3.ZERO


func _ready() -> void:
	var body := get_parent() as Node3D
	if body:
		_from = body.global_position


func _physics_process(_delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null:
		queue_free()
		return
	var push := direction * speed
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling and tumbling.is_on():
		tumbling.add_velocity(push)
		print("empuje %s en tumbo: +(%.2f, %.2f, %.2f) m/s" % [ShotImpact.who(body), push.x, push.y, push.z])
		_end(body)
		return
	if BodyNudge.push(body, push):
		_moved += push.length() / BodyNudge.TICKS
	_done += 1
	if _done >= duration_ticks:
		_end(body)


func _end(body: Node3D) -> void:
	set_physics_process(false)
	var at := body.global_position
	print("empuje %s %.2f m en %d ticks (dx %.2f, dz %.2f, dy %.2f) (cuadro %d)" % [ShotImpact.who(body), _moved, _done,
		at.x - _from.x, at.z - _from.z, at.y - _from.y, MatchClock.now()])
	queue_free()
