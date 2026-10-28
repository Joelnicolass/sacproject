class_name RevivingState
extends UnitState

## REVIVING: a Convert doctor is pumping this body back to life. For the game it is nobody's
## creature until the doctor takes it: no target, no attacks. Captive does the rest (health, groups,
## collision) and the look is not its business.


func present(_animate: bool) -> void:
	body.target = null
	body.engagement.cancel_attacks()
