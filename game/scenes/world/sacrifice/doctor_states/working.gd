extends FsmState

## Stands still on the spot doing `body.work` (pump, lift, torture). Regenerates. The ritual or
## the errand that asked for it ends it with end_work(). Server only.

var body: DoctorBody:
	get:
		return actor as DoctorBody


func enter() -> void:
	super.enter()
	body.pose = DoctorBody.Pose.WORKING
	body.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	body.regenerate(delta)
	body.advance_on_ground(Vector3.ZERO, delta)
