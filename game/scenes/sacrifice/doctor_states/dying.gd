extends FsmState

## Dead: no collision, out of the «doctor» group (DoctorBody does it from the pose), `died` fires
## and after `rules.doctor_death_s` the body frees itself. No corpse, no soul. Server only.

var body: DoctorBody:
	get:
		return actor as DoctorBody

var _left := 0.0


func enter() -> void:
	super.enter()
	body.pose = DoctorBody.Pose.DYING
	body.velocity = Vector3.ZERO
	_left = body.rules.doctor_death_s if body.rules else 2.0
	body.announce_death()


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		body.queue_free()
