class_name AttackState
extends UnitState

## ATTACK (meleeAttacking): faces the target, closes in while the swing plays and goes back to CHASE when it ends.


func physics_update(delta: float) -> void:
	var melee := body.get_node("MeleeAttack")
	var foe := body.target
	if body.accepts_target(foe):
		var to_foe := (foe.global_position - body.global_position) * Vector3(1.0, 0.0, 1.0)
		if to_foe.length_squared() > 0.000001:
			body.turn_toward(to_foe.normalized(), delta)
		body.velocity += melee.call("close_in", foe, 0.0 if body.afflictions.fixed() else body.move_speed * body.speed_factor, delta)
	if not melee.call("advance", delta):
		transition(&"Chase")


func clip_role() -> String:
	return "attack"
