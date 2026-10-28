extends RitualStep

## The doctors turn to the site and torture the creature (the rope shows it: doctor.carried). Within the
## window rules.ritual_drain_start_s .. + ritual_drain_s the wizard loses a round's worth of life and
## mana, evenly (RitualDrain). At the end: complete or wait.

const FACING_TOLERANCE := 0.05


func enter() -> void:
	super.enter()
	ritual.phase = Ritual.Phase.SHOOT
	for doctor in ritual.doctors:
		doctor.stop()


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var rules := ritual.rules
	_torture(delta)
	var from := rules.ritual_drain_start_s
	var to := minf(from + rules.ritual_drain_s, rules.ritual_shoot_s)
	if to > from:
		var overlap := minf(time, to) - maxf(time - delta, from)
		if overlap > 0.0 and ritual.drain != null:
			ritual.drain.apply(overlap / (to - from))
	if time >= rules.ritual_shoot_s:
		ritual.finish_round()


## Turns each doctor to the center; once facing it, it works (pose torture) and its rope reaches the creature.
func _torture(delta: float) -> void:
	for doctor in ritual.doctors:
		if doctor.pose == DoctorBody.Pose.WORKING:
			continue
		var wanted := SacrificeMath.yaw_toward(doctor.global_position, ritual.center())
		doctor.turn_toward(Vector3(sin(wanted), 0.0, cos(wanted)), delta)
		if absf(angle_difference(doctor.rotation.y, wanted)) <= FACING_TOLERANCE:
			doctor.begin_work(DoctorBody.Work.TORTURE)
			if is_instance_valid(ritual.creature):
				doctor.carried = ritual.creature.get_path()
