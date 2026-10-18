class_name ShootState
extends UnitState

## SHOOT (sacengine shooting): stands, keeps facing the aim and fires on the shoot tick.


func physics_update(delta: float) -> void:
	var ranged := body.get_node("RangedAttack")
	if body.accepts_target(body.target):
		body.turn_toward(ranged.call("aim_direction", body.target), delta)
	if not ranged.call("advance", delta):
		transition(&"Chase")
