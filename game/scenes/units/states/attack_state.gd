class_name AttackState
extends UnitState

## ATTACK (meleeAttacking): faces the target, closes in while the swing plays and goes back to CHASE when it ends.

## Role of each slot of CreatureType.melee_animations.
const ATTACK_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]


func physics_update(delta: float) -> void:
	var melee := body.get_node("MeleeAttack") as MeleeAttack
	var foe := body.target
	if body.accepts_target(foe):
		var to_foe := (foe.global_position - body.global_position) * Vector3(1.0, 0.0, 1.0)
		if to_foe.length_squared() > 0.000001:
			body.turn_toward(to_foe.normalized(), delta)
		body.velocity += melee.close_in(foe, 0.0 if body.afflictions.fixed() else body.move_speed * body.speed_factor, delta)
	if not melee.advance(delta):
		transition(&"Chase")


## F336: the clip of the swing that was picked: attack, attack2 or attack3 when the model has them, else attack.
func clip_role() -> String:
	var index := (body.get_node("MeleeAttack") as MeleeAttack).swing_index()
	if index > 0 and body.has_clip(ATTACK_ROLES[index]):
		return ATTACK_ROLES[index]
	return "attack"
