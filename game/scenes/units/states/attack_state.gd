class_name AttackState
extends UnitState

## ATTACK: faces the target, closes in while the swing plays and goes back to CHASE when it ends.


func physics_update(delta: float) -> void:
	var melee := body.weapons.melee
	var foe := body.target
	if body.engagement.accepts_target(foe):
		var to_foe := (foe.global_position - body.global_position) * Vector3(1.0, 0.0, 1.0)
		if to_foe.length_squared() > 0.000001:
			body.locomotion.turn_toward(to_foe.normalized(), delta)
		body.velocity += melee.close_in(foe, 0.0 if body.afflictions.fixed() else body.move_speed * body.speed_factor, delta)
	if not melee.advance(delta):
		transition(&"Chase")


## The clip of the swing that was picked (MeleeWeapon): attack, attack2 or attack3 when the model has them, else attack.
func clip_role() -> String:
	return body.weapons.melee.clip_role()
