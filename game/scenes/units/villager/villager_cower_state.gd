class_name VillagerCowerState
extends VillagerState

## COWER: no shelter within reach. It crouches where it is until something else moves it.


func act() -> void:
	body.engagement.cower()
