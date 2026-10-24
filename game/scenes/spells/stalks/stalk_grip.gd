class_name StalkGrip
extends Node

## The body one stalk holds: it throws it into the air when the stalk catches it, keeps its centre on the tip while the stalk lifts it and
## throws it with the speed of the tip when it lets go. The only writer of the position of a body that hangs from a stalk. It does not
## say when to catch or release (Stalk does) and it does not land the body (Tumbling does). Server only.
## Ref: sacengine updateMeanstalk, modes grabbing, holding and throwing (state.d:22618-22653, 22682-22688).

var _body: Node3D
var _tip := Vector3.ZERO
var _velocity := Vector3.ZERO


func _ready() -> void:
	## After the body has moved this tick, so the tip is the last word on where it hangs.
	process_physics_priority = 1
	set_physics_process(false)


## The body hanging from the stalk, or null.
func held() -> Node3D:
	return _body if holds() else null


## True while a body hangs from the tip: still there, still thrown into the air.
func holds() -> bool:
	if _body == null or not is_instance_valid(_body):
		return false
	var tumbling := BodyNudge.tumbling_of(_body)
	return tumbling != null and tumbling.is_on()


## Throws `body` up with the tip's speed (never down) and starts holding it. False when it cannot be thrown (a flier, a frozen or dead body).
func catch(body: Node3D, slot: int, tip_velocity: Vector3) -> bool:
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling == null:
		return false
	var push := tip_velocity
	push.y = maxf(push.y, 0.0) + tumbling.falling_acceleration / MatchClock.TICKS_PER_SECOND_F
	if not tumbling.catapult(push, slot):
		return false
	_body = body
	set_physics_process(true)
	return true


## The tip's place and speed this tick; the body is put there after it has moved.
func follow(tip: Vector3, velocity: Vector3) -> void:
	_tip = tip
	_velocity = velocity


## Lets go with the speed of the tip (plus the pull of one tick's gravity): the body flies on and Tumbling lands it.
func throw(velocity: Vector3) -> void:
	var tumbling := BodyNudge.tumbling_of(_body) if _body != null and is_instance_valid(_body) else null
	if tumbling != null and tumbling.is_on():
		tumbling.drive(velocity + Vector3.UP * tumbling.falling_acceleration / MatchClock.TICKS_PER_SECOND_F)
	drop()


## Lets go with the speed the body has (the stalk went away).
func drop() -> void:
	_body = null
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not holds():
		return
	_body.global_position += _tip - BodyNudge.center(_body)
	BodyNudge.tumbling_of(_body).drive(_velocity)
