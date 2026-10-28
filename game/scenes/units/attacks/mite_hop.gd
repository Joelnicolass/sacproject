class_name MiteHop
extends ShotInFlight

## The Bilemite (liba) hops (the branch of a mite that has not stuck
## yet): on every update position += v/60 and then v.z -= g/60 (g = ability.fallingAcceleration, 20; RangedShot does both
## and calls fly() after them), and when the land is above it (isOnGround and getGroundHeight > position.z):
##   - it is put on the ground and numJumps += 1;
##   - the 5th touch (numJumps >= 5) stops it (v = 0): it stays there and is gone 30 updates later (vanish: alpha -= 1/(fadeTime·60));
##   - else it hops towards the closest creature (closestCreatureInRange: range ability.effectRange =
##     15, only bodies whose feet are at most 10 m over the land, any side, the shooter too): the intended target when it is
##     within the range instead of that one: v = 4.5·direction + 0.5·uniformDirection, then
##     v.z += 0.5·g·|direction| / |v| and v.z = min(v.z, 10);
##   - with nobody there: v = 5·uniformDirection and v.z = 10.
## This node owns the shot's height (holds_height): RangedShot does not burst it on the ground, the mite ends on the 5th touch
## (spent()) or when RangedShot's box finds a body (ShotLook.hits_every_side: StickImpact sticks it to whoever it touches).
## The stream is MatchSeed.rng(["mites", shot name]): the same match gives the same hops (R11). uniformDirection is the cube
## [-1, 1]^3 normalized, 3 draws, as LobAbility's.
## The intended target comes in the packet (spawn_data "intended": the path of the body the ability was aimed at, "" = none).
## Divergences (declared): the land is the terrain's (a roof is not ground); a mite over a hole (no land) never touches and flies
## until RangedShot's range ends; a stopped mite can still stick to a body that touches it in its last 30 ticks (the original skips
## the collision once it has stopped).
## Server (or solo) only: RangedShot instances this node there only.
## Ref: F156 (RFC-030 030s-b), sacengine updateBlightMite state.d:25271-25340, closestCreatureInRange 25235-25260 and state.d:28778, 25311-25318, uniformDirection state.d:29106-29111.

## The mite stops on this touch number.
@export var jumps := 5
## How long a stopped mite stays before it is gone (the fade).
@export_range(0.0, 5.0, 0.0001, "suffix:s") var rest_s := 0.5
## A body whose feet are higher over the land than this is not a target (closestCreatureInRange limit).
@export var max_target_height := 10.0
## Range of the search when the shot has no SPEL (ability.effect_range_m is the rule).
@export var fallback_range := 15.0
## v = hop_speed · direction + wobble · uniformDirection.
@export var hop_speed := 4.5
@export var wobble := 0.5
## v.y never goes over this after the lift of the arc.
@export var max_rise_speed := 10.0
## With nobody in range: v = idle_speed · uniformDirection and v.y = idle_rise.
@export var idle_speed := 5.0
@export var idle_rise := 10.0

var _rng: RandomNumberGenerator
var _shot_name := ""
var _shape: Terrain
var _touches := 0
var _stopped_at := -1
var _rest := Vector3.ZERO
var _released := false


func holds_height() -> bool:
	return true


## True once the mite has been stopped for `rest_s`. RangedShot frees the shot when it is (F156: ShotInFlight.spent()).
func spent() -> bool:
	if _stopped_at < 0 or ticks - _stopped_at < MatchClock.ticks_for(rest_s):
		return false
	if DebugLog.on(&"hop") and not _released:
		print("acaro %s suelto (tick %d)" % [_shot_name, MatchClock.now()])
	_released = true
	return true



func _fly(shot: RangedShot, at: Vector3) -> void:
	if _rng == null:
		_shot_name = String(shot.name)
		_rng = MatchSeed.rng(["mites", _shot_name])
	if _stopped_at >= 0:
		## Stopped: RangedShot moved it and pulled it down; put it back.
		shot.velocity = Vector3.ZERO
		shot.global_position = _rest
		return
	var shape := _land(shot)
	if shape == null or not shape.is_on_ground(at.x, at.z):
		return
	var ground := shape.height_at(at.x, at.z)
	if ground <= at.y:
		return
	var here := Vector3(at.x, ground, at.z)
	shot.global_position = here
	_touches += 1
	if _touches >= jumps:
		_stopped_at = ticks
		_rest = here
		shot.velocity = Vector3.ZERO
		if DebugLog.on(&"hop"):
			print("salto %s n=%d en %s parado (tick %d)" % [_shot_name, _touches, _vec(here), MatchClock.now()])
		return
	var close := _closest(shot, here, shape)
	var chosen := _intended(shot, here, close, shape)
	var velocity := shot.velocity
	var aim := "nadie"
	if chosen != null:
		var direction := BodyNudge.center(chosen) - here
		velocity = hop_speed * direction.normalized() + wobble * _uniform_direction()
		if velocity.length() > 0.0:
			velocity.y += 0.5 * shot.gravity * direction.length() / velocity.length()
		velocity.y = minf(velocity.y, max_rise_speed)
		aim = String(chosen.name)
	elif close == null:
		velocity = idle_speed * _uniform_direction()
		velocity.y = idle_rise
	shot.velocity = velocity
	if DebugLog.on(&"hop"):
		print("salto %s n=%d en %s v %s hacia %s (tick %d)" % [_shot_name, _touches, _vec(here), _vec(velocity), aim, MatchClock.now()])


## The closest live creature or wizard within the range, any side, whose feet are at most max_target_height over the land.
func _closest(shot: RangedShot, from: Vector3, shape: Terrain) -> Node3D:
	var reach := _reach(shot)
	var best: Node3D = null
	var best_d := INF
	for group in [&"unit", &"wizard"]:
		for node in shot.get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not _is_target(body):
				continue
			var d := from.distance_squared_to(BodyNudge.center(body))
			if d > reach * reach or d >= best_d:
				continue
			if not _low_enough(body, shape):
				continue
			best = body
			best_d = d
	return best


## Its feet are at most max_target_height over the land (or it is off the land).
func _low_enough(body: Node3D, shape: Terrain) -> bool:
	if shape == null or not shape.is_on_ground(body.global_position.x, body.global_position.z):
		return true
	return body.global_position.y <= shape.height_at(body.global_position.x, body.global_position.z) + max_target_height


## `close`, or the intended target when it is within the range (it goes first).
func _intended(shot: RangedShot, from: Vector3, close: Node3D, shape: Terrain) -> Node3D:
	var path := String(shot.spawn_data.get("intended", ""))
	if path.is_empty() or close == null:
		return close
	var intended := shot.get_node_or_null(NodePath(path)) as Node3D
	if intended == null or intended == close or not _is_target(intended) or not _low_enough(intended, shape):
		return close
	var reach := _reach(shot)
	return intended if from.distance_squared_to(BodyNudge.center(intended)) <= reach * reach else close


func _is_target(body: Node3D) -> bool:
	return is_instance_valid(body) and ProjectileTargets.is_live_body(body)


func _reach(shot: RangedShot) -> float:
	return shot.ability.effect_range_m if shot.ability != null and shot.ability.effect_range_m > 0.0 else fallback_range


func _land(shot: RangedShot) -> Terrain:
	if _shape == null or not is_instance_valid(_shape):
		_shape = shot.get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain
	return _shape


## A point of the cube [-1, 1]^3, normalized (3 draws). The draws are the simulation's.
func _uniform_direction() -> Vector3:
	return LobAbility.uniform_direction(_rng)


static func _vec(v: Vector3) -> String:
	return "(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]
