class_name ShootState
extends UnitState

## SHOOT (sacengine shooting): stands, keeps facing the aim and fires on the shoot tick.


func physics_update(delta: float) -> void:
	var ranged := body.get_node("RangedAttack") as RangedAttack
	if body.accepts_target(body.target):
		body.turn_toward(ranged.aim_direction(body.target), delta)
	if not ranged.advance(delta):
		transition(&"Chase")


## The shot clip (role `shoot`) when the model has it, else the rest pose.
func clip_role() -> String:
	return "shoot" if body.has_clip("shoot") else "idle"
