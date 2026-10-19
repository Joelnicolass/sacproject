class_name MoveState
extends UnitState

## MOVE: straight toward the goal of begin_walk at the pace of the body; arrives within one step of it.


func physics_update(delta: float) -> void:
	body.air.reroute()
	var goal := body.walk_goal()
	var pace := body.move_speed * body.speed_factor
	var flat := Vector3(goal.x - body.global_position.x, 0.0, goal.z - body.global_position.z)
	if pace <= 0.0 or flat.length() <= pace * delta:
		transition(&"Idle")
		return
	var direction := flat.normalized()
	body.turn_toward(direction, delta)
	body.velocity.x = direction.x * pace
	body.velocity.z = direction.z * pace


func clip_role() -> String:
	return "run"
