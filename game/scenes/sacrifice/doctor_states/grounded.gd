extends FsmState

## On the ground: walks to the goal of `body.motor` when it has one, else stands. Regenerates all
## the time. Server only.

var body: DoctorBody:
	get:
		return actor as DoctorBody


func physics_update(delta: float) -> void:
	var wanted := DoctorBody.Pose.WALKING if body.is_walking() else DoctorBody.Pose.IDLE
	if body.pose != wanted:
		body.pose = wanted
	body.regenerate(delta)
	var motor := body.motor
	if not body.is_walking():
		motor.advance_on_ground(Vector3.ZERO, delta)
		return
	var flat := Vector3(
		motor.goal.x - body.global_position.x, 0.0, motor.goal.z - body.global_position.z
	)
	var pace := body.pace()
	if pace <= 0.0 or flat.length() <= maxf(motor.arrive_distance_m, pace * delta):
		var reached := motor.goal
		body.stand()
		body.arrived.emit(reached)
		return
	var direction := flat.normalized()
	if motor.dodge_left > 0.0:
		motor.dodge_left -= delta
		direction = direction.rotated(Vector3.UP, motor.dodge_angle)
	motor.turn_toward(direction, delta)
	motor.advance_on_ground(direction * pace * maxf(0.0, body.facing_flat().dot(direction)), delta)
