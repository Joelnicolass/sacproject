extends FsmState

## Invulnerable (the body is not targetable while FALLING). A ballistic arc under the engine gravity
## from where the body is to `body.landing`; on touching the ground it stands still for
## `rules.doctor_bounce_s` (the original `bounce`) and then `landed` fires. Server only.

var body: DoctorBody:
	get:
		return actor as DoctorBody

var _bounce_left := -1.0


func enter() -> void:
	super.enter()
	body.pose = DoctorBody.Pose.FALLING
	_bounce_left = -1.0
	var rise := body.global_position.y - body.landing.y
	var fall_s := sqrt(2.0 * maxf(rise, 0.0) / DoctorBody.gravity())
	var flat := Vector3(body.landing.x - body.global_position.x, 0.0, body.landing.z - body.global_position.z)
	body.velocity = Vector3.ZERO if fall_s <= 0.0 else flat / fall_s


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
		_bounce_left = body.rules.doctor_bounce_s if body.rules else 1.0
	elif FallCheck.has_fallen(body):
		body.kill()
