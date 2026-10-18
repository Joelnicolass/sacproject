class_name ChaseState
extends UnitState

## CHASE: toward the attack target; starts the melee swing or the shot when in range. Without an order it gives up
## beyond the sight range.

const _RANGED := preload("res://scenes/world/units/ranged_attack.gd")


func physics_update(delta: float) -> void:
	var foe := body.target
	if not body.accepts_target(foe) or (not body.ordered and body.flat_distance(foe) > body.sight_range()):
		body.target = null
		transition(&"Idle")
		return
	var ranged := body.get_node("RangedAttack")
	var shooting := bool(ranged.call("prefers", foe))
	if shooting:
		var step: int = ranged.call("aim", foe)
		if step != _RANGED.Step.APPROACH:
			body.turn_toward(ranged.call("aim_direction", foe), delta)
			if step == _RANGED.Step.FIRE:
				body.shots += 1
				transition(&"Shoot")
			return
	var melee := body.get_node("MeleeAttack")
	if not shooting and melee.call("can_start", foe):
		melee.call("start", foe)
		body.swings += 1
		transition(&"Attack")
		return
	var heading := foe.global_position
	if is_instance_valid(body.path_follower):
		heading = body.path_follower.call("steer_point", heading)
	var to_foe := heading - body.global_position
	to_foe.y = 0.0
	if to_foe.length_squared() < 0.000001:
		return
	var direction := to_foe.normalized()
	body.turn_toward(direction, delta)
	var pace := body.move_speed * body.speed_factor * maxf(0.0, body.facing_flat().dot(direction))
	body.velocity.x = direction.x * pace
	body.velocity.z = direction.z * pace


func clip_role() -> String:
	return "run"
