extends RitualStep

## Each doctor walks a quarter turn around the site; the radius shrinks from 20 to 17 m in the last
## fifth (sacengine ritualPositions, state.d:15854-15863, 15953-15972). Rounds start one quarter further.


func enter() -> void:
	super.enter()
	ritual.phase = Ritual.Phase.WALK
	for doctor in ritual.doctors:
		doctor.end_work()
		doctor.carried = NodePath()


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	var rules := ritual.rules
	var progress := clampf(time / rules.ritual_walk_s, 0.0, 1.0)
	for k in ritual.doctors.size():
		var point := SacrificeMath.ring_point(ritual.center(), k + ritual.round_index, progress, rules.ritual_radius, rules.ritual_walk_shrink)
		ritual.doctors[k].walk_to(point)
	if time >= rules.ritual_walk_s:
		transition(&"Shoot")
