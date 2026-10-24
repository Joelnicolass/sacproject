class_name StalkHunt
extends Node

## What a stalk hunts and how fast it moves while it does: which body it may take (alive, not frozen, not caught by this cast before, inside
## the 10 to 45 m band of its root), the nearest such body in reach, and the speeds of its tip. It does not move the tip (Stalk does) nor hold
## the body (StalkGrip does). Server only.
## Ref: sacengine findMeanstalkTarget, meanstalkCheckTarget (state.d:22544-22573).

const BODY_GROUPS: Array[StringName] = [&"wizard", &"unit"]

## Who this cast has caught already.
@export var roster: StalkRoster
@export_group("Tip")
## The tip catches a body at this distance from its box.
@export_range(0.01, 5.0, 0.01, "suffix:m") var catch_m := 0.1
## The held body is thrown when the tip is this close to the top.
@export_range(0.0, 50.0, 0.1, "suffix:m") var release_m := 7.0
## Without prey the tip drifts inside a cone of this radius over the root, at this speed and acceleration.
@export_range(1.0, 100.0, 0.5, "suffix:m") var wander_m := 30.0
@export_range(0.1, 50.0, 0.1, "suffix:m/s") var wander_speed := 6.0
@export_range(0.1, 50.0, 0.1) var wander_accel := 0.6
## With a body in its grip the tip lifts it at this speed and acceleration.
@export_range(0.1, 100.0, 0.1, "suffix:m/s") var lift_speed := 42.0
@export_range(0.1, 50.0, 0.1) var lift_accel := 4.2

var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = MatchSeed.rng(["stalk", String(get_path())])


## A point of the cone over `base` the tip drifts to.
func wander_goal(base: Vector3, height_m: float) -> Vector3:
	return StalkRules.wander_point(base, _rng.randf_range(-PI / 4.0, PI / 4.0), _rng.randf_range(0.0, TAU), wander_m, height_m)


## The nearest body within `reach_m` of `base` that `takeable` allows (by its feet), or null.
func pick(base: Vector3, reach_m: float) -> Node3D:
	var best: Node3D = null
	var best_sq := INF
	for body in SplashDamage.bodies_within(get_tree(), base, reach_m, null, BODY_GROUPS):
		var sq := (body.global_position - base).length_squared()
		if sq < best_sq and sq < reach_m * reach_m and takeable(body, body.global_position, base):
			best = body
			best_sq = sq
	return best


func takeable(body: Node3D, at: Vector3, base: Vector3) -> bool:
	return StalkRules.is_live(body) and not roster.has(body) and not BodyNudge.fixed(body) and StalkRules.in_pick_band(base, at)
