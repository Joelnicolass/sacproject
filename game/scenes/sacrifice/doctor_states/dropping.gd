extends FsmState

## Invulnerable (the body is not targetable while it falls or lands). It leaves the vortex going up at
## `body.launch_up_m_s`, falls under the engine gravity to `body.landing` holding the last frame of the
## expelled clip, plays the hit-floor clip once on touching the ground and then `landed` fires. Server only.
## Ref: state.d:15480-15504 (launch), 14184-14190 and 14220-14224 (expelled, hitFloor).

var body: DoctorBody:
	get:
		return actor as DoctorBody

var _bounce_left := -1.0


func enter() -> void:
	super.enter()
	body.pose = DoctorBody.Pose.FALLING
	_bounce_left = -1.0
	var rise := body.global_position.y - body.landing.y
	var g := DoctorBody.gravity()
	var up := body.launch_up_m_s
	var fall_s := (up + sqrt(up * up + 2.0 * g * maxf(rise, 0.0))) / g
	var flat := Vector3(body.landing.x - body.global_position.x, 0.0, body.landing.z - body.global_position.z)
	body.velocity = Vector3(flat.x / fall_s, up, flat.z / fall_s)


func physics_update(delta: float) -> void:
	if _bounce_left >= 0.0:
		body.advance_on_ground(Vector3.ZERO, delta)
		_bounce_left -= delta
		if _bounce_left <= 0.0:
			body.landed.emit()
			transition(&"Grounded")
		return
	body.velocity.y -= DoctorBody.gravity() * delta
	body.move_and_slide()
	if body.is_on_floor():
		body.velocity = Vector3.ZERO
		body.pose = DoctorBody.Pose.LANDING
		_bounce_left = body.landing_s()
	elif FallCheck.has_fallen(body):
		body.kill()
