class_name ErrandStep
extends FsmState

## One step of a carrier's errand. If the doctor dies, CarryErrand undoes what any step did with one rule.
## Server only: the Steps machine does not run on clients.

var errand: CarryErrand:
	get:
		return actor as CarryErrand
