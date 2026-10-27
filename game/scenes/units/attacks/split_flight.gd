class_name ShotSplit
extends ShotInFlight

## The Boulderdash's fan of three rocks (emba).
## RangedWeapon fires ShotLook.volley shots with the same direction (one accuracy roll) and writes in each spawn packet
## its `volley_index` (−1, 0, +1) and `aim_distance` (|aim point − origin|). This node counts
## distanceUntilSplit = max(0, aim_distance − before_target_m) down by speed/60 on every tick of the flight; on the tick
## it goes under 0 the side rocks turn volley_index · angle_deg around `axis` (the original: the shooter's «up»), after the
## move of that tick, so the new direction counts from the next move (the order of updateBoulderdashProjectile).
## The middle rock (index 0) never turns. Without `aim_distance` in the packet nothing splits.
## Deviation (declared): the turn is around Vector3.UP, not the shooter's own up (a ground shooter stands upright); with
## the port's axes it may come out mirrored, and the fan is symmetric.
## Ref: F125 (RFC-030 030n-a), sacengine boulderdashShoot state.d:11793-11813, 11794, updateBoulderdashProjectile 24729-24755, θ 24740.


## The turn of each side rock (θ = 3.5°).
@export var angle_deg := 3.5
## The rocks split this far before the aim point (boulderdashSplitDistance).
@export var before_target_m := 60.0
## The axis the side rocks turn around.
@export var axis := Vector3.UP

## distanceUntilSplit; < 0 once split (or with no aim in the packet).
var _until := -1.0
var _index := 0
var _split_tick := 0
var _last_at := Vector3.ZERO
var _shot_name := ""


func _fly(shot: RangedShot, at: Vector3) -> void:
	_last_at = at
	if ticks == 1:
		_begin(shot, at)
	if _until < 0.0:
		return
	_until -= _step_m(shot)
	if _until < 0.0:
		_split(shot)


func _begin(shot: RangedShot, at: Vector3) -> void:
	_shot_name = String(shot.name)
	var data := shot.spawn_data
	_index = int(data.get("volley_index", 0))
	var aim := float(data.get("aim_distance", -1.0))
	_until = maxf(0.0, aim - before_target_m) if aim >= 0.0 else -1.0
	if DebugLog.on(&"split"):
		_log_start(shot, at, aim)


## velocity = rotate(rotationQuaternion(upwards, which·θ), velocity) for which ≠ 0.
func _split(shot: RangedShot) -> void:
	_split_tick = ticks
	var before := shot.velocity
	if _index != 0:
		shot.velocity = before.rotated(axis.normalized(), float(_index) * deg_to_rad(angle_deg))
	if DebugLog.on(&"split"):
		var direction := shot.velocity.normalized()
		print("abanico ±%s° a los %.3f m: %s índice %d tick %d ángulo %.4f° visto desde arriba dir (%.5f, %.5f, %.5f) (cuadro %d)" % [
			_comma(angle_deg), _split_at(shot), shot.name, _index, ticks, _flat_angle_deg(before, shot.velocity),
			direction.x, direction.y, direction.z, MatchClock.now()])


## It decrements distanceUntilSplit by rangedAttack.speed/updateFPS; without a SPEL, by the shot's own speed.
func _step_m(shot: RangedShot) -> float:
	var speed := shot.ability.speed_m_s if shot.ability else shot.velocity.length()
	return speed / MatchClock.TICKS_PER_SECOND_F


## The distance the packet asked to split at (for the log): max(0, aim_distance − before_target_m).
func _split_at(shot: RangedShot) -> float:
	return maxf(0.0, float(shot.spawn_data.get("aim_distance", 0.0)) - before_target_m)


## The turn seen from above, in degrees (sign by the port's axes): the rotation is around UP, so this is exactly
## index · angle_deg whatever the rock's slope.
static func _flat_angle_deg(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(Vector2(from.x, from.z).angle_to(Vector2(to.x, to.z)))


static func _comma(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


func _log_start(shot: RangedShot, at: Vector3, aim: float) -> void:
	var direction := shot.velocity.normalized()
	var target := shot.get_node_or_null(shot.target_path) if not shot.target_path.is_empty() else null
	var shooter := shot.get_node_or_null(shot.shooter_path) if not shot.shooter_path.is_empty() else null
	print("abanico %s índice %d tick 1 en (%.3f, %.3f, %.3f) dir (%.5f, %.5f, %.5f) paso %.4f apuntado %.3f m giro a los %.3f m alcance %.1f caja %.2f blanco %s tirador %s bando %d (cuadro %d)" % [
		shot.name, _index, at.x, at.y, at.z, direction.x, direction.y, direction.z, _step_m(shot), aim, _until,
		shot.max_distance, shot.look.hit_size if shot.look else 0.0, str(target.name) if target else "nadie",
		str(shooter.name) if shooter else "nadie", shot.from_slot, MatchClock.now()])
	if _index != 0:
		return
	## The bodies the rocks may hit, once per volley (the middle rock): the replica walks the same boxes.
	for group: StringName in [&"wizard", &"unit"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not Attackable.is_body(body):
				continue
			var box := BodyNudge.box(body)
			var center := box.get_center()
			var half := box.size * 0.5
			var side := int(body.get("owner_slot")) if "owner_slot" in body else 0
			print("abanico %s cuerpo %s caja (%.3f, %.3f, %.3f) ± (%.3f, %.3f, %.3f) bando %d" % [shot.name, body.name,
				center.x, center.y, center.z, half.x, half.y, half.z, side])


## The rock's last tick: where it was when it burst (or reached its range), and the body its box touches there (the log
## only: RangedShot decides the hit).
func _exit_tree() -> void:
	if ticks == 0 or not DebugLog.on(&"split"):
		return
	var size := 0.7
	var shot := get_parent() as RangedShot
	if shot and shot.look:
		size = shot.look.hit_size
	var touched := "nadie"
	var area := AABB(_last_at - Vector3.ONE * size * 0.5, Vector3.ONE * size)
	for body in BodyNudge.bodies_in(get_tree(), area):
		touched = str(body.name)
		break
	print("abanico %s índice %d fin tick %d en (%.3f, %.3f, %.3f) giro tick %d toca %s (cuadro %d)" % [_shot_name, _index,
		ticks, _last_at.x, _last_at.y, _last_at.z, _split_tick, touched, MatchClock.now()])
