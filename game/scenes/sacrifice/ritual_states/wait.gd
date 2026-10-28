extends RitualStep

## The doctors let go and rest (rules.ritual_wait_s, 4.5 s); then the next round starts a quarter
## turn on.


func enter() -> void:
	super.enter()
	ritual.phase = Ritual.Phase.WAIT
	for doctor in ritual.doctors:
		doctor.end_work()
		doctor.carried = NodePath()


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	if time >= ritual.rules.ritual_wait_s:
		ritual.round_index += 1
		transition(&"Walk")
