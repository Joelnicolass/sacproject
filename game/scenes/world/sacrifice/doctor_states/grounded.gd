extends FsmState

## On the ground: walks to `body.goal` when it has one, else stands. Regenerates all the time.
## Server only.

var body: DoctorBody:
	get:
		return actor as DoctorBody


func physics_update(delta: float) -> void:
	var wanted := DoctorBody.Pose.WALKING if body.is_walking() else DoctorBody.Pose.IDLE
	if body.pose != wanted:
		body.pose = wanted
	body.regenerate(delta)
	if not body.is_walking():
		body.advance_on_ground(Vector3.ZERO, delta)
		return
	var flat := Vector3(body.goal.x - body.global_position.x, 0.0, body.goal.z - body.global_position.z)
	var pace := body.pace()
	if pace <= 0.0 or flat.length() <= maxf(body.arrive_distance, pace * delta):
		var reached := body.goal
		body.stand()
		body.arrived.emit(reached)
		return
	var direction := flat.normalized()
	if body.dodge_left > 0.0:
		body.dodge_left -= delta
		direction = direction.rotated(Vector3.UP, body.dodge_angle)
	body.turn_toward(direction, delta)
	body.advance_on_ground(direction * pace * maxf(0.0, body.facing_flat().dot(direction)), delta)
