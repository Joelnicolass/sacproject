class_name Pushback
extends Node

## Squall's push. A child of the
## body it pushes (it goes with the body), server (or solo) only. For `duration_s` it pushes the body at
## `speed` m/s along the shot (BodyNudge.push: it slides on the land, a step off the land is not taken). A thrown body
## (Tumbling on) gets the velocity once and the push ends. Effects run before the creatures: the
## node's physics priority is −1, so it pushes before the body moves.

## The push is 15 m in 2/3 s.
@export var speed := 22.5
@export_range(0.0, 10.0, 0.0001, "suffix:s") var duration_s := 0.6666

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
		print(
			(
				"push %s while tumbling: +(%.2f, %.2f, %.2f) m/s"
				% [GameBody.name_of(body), push.x, push.y, push.z]
			)
		)
		_end(body)
		return
	if BodyNudge.push(body, push):
		_moved += push.length() / MatchClock.TICKS_PER_SECOND_F
	_done += 1
	if _done >= MatchClock.ticks_for(duration_s):
		_end(body)


func _end(body: Node3D) -> void:
	set_physics_process(false)
	var at := body.global_position
	print(
		(
			"push %s %.2f m in %d ticks (dx %.2f, dz %.2f, dy %.2f) (frame %d)"
			% [
				GameBody.name_of(body),
				_moved,
				_done,
				at.x - _from.x,
				at.z - _from.z,
				at.y - _from.y,
				MatchClock.now()
			]
		)
	)
	queue_free()
