class_name VillagerWorkState
extends VillagerState

## WORK: shelter near and nothing scary in sight. It stands still where it is (the body plays the work clip in IDLE, see VillagerBrain).


func act() -> void:
	if body.mode == UnitBody.Mode.MOVE:
		body.halt()
