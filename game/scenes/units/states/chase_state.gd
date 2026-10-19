class_name ChaseState
extends UnitState

## CHASE: toward the attack target; starts the melee swing or the shot when in range. Without an order it gives up
## beyond the sight range.
## F376 (RFC-053 053g): a chase that does not move (turning in place, held by the avoidance, under a flier it cannot reach)
## shows the rest clip instead of `run` on the spot once its flat speed stays under `still_speed` for `still_after_s`. Only the
## clip: measured on every peer from the body's real displacement, the simulation never reads it.

## Below this flat speed (m/s) the chase is standing.
@export var still_speed := 0.1
## Seconds standing before the clip turns to idle (a turn at the start of a chase still runs).
@export var still_after_s := 0.2

var _still_ticks := 0
var _seen_frame := -1
var _last_position := Vector3.ZERO


func enter() -> void:
	_still_ticks = 0
	_seen_frame = -1
	super.enter()


func physics_update(delta: float) -> void:
	var foe := body.target
	if not body.accepts_target(foe) or (not body.ordered and body.flat_distance(foe) > body.sight_range()):
		body.target = null
		transition(&"Idle")
		return
	var ranged := body.get_node("RangedAttack") as RangedAttack
	var shooting := ranged.prefers(foe)
	if shooting:
		var step := ranged.aim(foe)
		if step != RangedAttack.Step.APPROACH:
			body.turn_toward(ranged.aim_direction(foe), delta)
			if step == RangedAttack.Step.FIRE:
				body.shots += 1
				transition(&"Shoot")
			return
	var melee := body.get_node("MeleeAttack") as MeleeAttack
	if not shooting and melee.can_start(foe):
		melee.start(foe)
		body.swings += 1
		transition(&"Attack")
		return
	var heading := foe.global_position
	if is_instance_valid(body.path_follower):
		heading = body.path_follower.steer_point(heading)
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
	_watch_pace()
	return "idle" if _still_ticks > MatchClock.ticks_for(still_after_s) else "run"


## Once per physics frame: how long the body has stood (its flat displacement since the last frame under still_speed).
func _watch_pace() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _seen_frame:
		return
	var at := body.global_position
	if _seen_frame >= 0:
		var frames := maxi(1, frame - _seen_frame)
		var speed := Vector2(at.x - _last_position.x, at.z - _last_position.z).length() * MatchClock.TICKS_PER_SECOND_F / frames
		_still_ticks = _still_ticks + frames if speed < still_speed else 0
	_seen_frame = frame
	_last_position = at
