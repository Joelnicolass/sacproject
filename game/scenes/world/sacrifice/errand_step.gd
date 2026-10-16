class_name ErrandStep
extends FsmState

## One step of a carrier's errand (RFC-020). A step knows what happens if the doctor dies while it
## is the current one: CarryErrand calls doctor_died() before it says the errand failed.
## Server only: the Steps machine does not run on clients.

var errand: CarryErrand:
	get:
		return actor as CarryErrand


## The doctor died while this step was current. Undo what the step did (let a creature go…).
func doctor_died() -> void:
	pass
