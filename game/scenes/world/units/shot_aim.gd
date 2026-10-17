class_name ShotAim
extends RefCounted

## F124 (RFC-030 030m): ranged accuracy, the one owner of the scatter of a creature's shot. RangedAttack draws it once
## per shot; a RayStrike that rerolls (the Warmonger, 030m-b) draws it again for every ray.


## sacengine applyRangedAccuracy (state.d:11491-11498): angle = atan(accuracy·0.001·0.14 + 0.03), azimuth angle·r³ and
## elevation 0.1·angle·r³ with r uniform in [−1, 1], azimuth drawn first. sacengine's z-up axes map to Godot as
## z → Y, x → X. The order of the draws is the simulation's: do not swap them.
static func scatter(direction: Vector3, accuracy: float, rng: RandomNumberGenerator) -> Vector3:
	var angle := atan(accuracy * 0.001 * 0.14 + 0.03)
	var azimuth_roll := rng.randf_range(-1.0, 1.0)
	var elevation_roll := rng.randf_range(-1.0, 1.0)
	var azimuth := angle * azimuth_roll * azimuth_roll * azimuth_roll
	var elevation := 0.1 * angle * elevation_roll * elevation_roll * elevation_roll
	return direction.rotated(Vector3.RIGHT, elevation).rotated(Vector3.UP, azimuth)


## Where a shot leaves a body: its front (melee_profile reach along facing_flat) at `height_fraction` of its height. The one
## owner of the origin: RangedAttack.shot_origin (its shot_height) and LobAbility (its own).
static func origin(body: Node3D, height_fraction: float) -> Vector3:
	var profile: Dictionary = body.call("melee_profile")
	var facing: Vector3 = body.call("facing_flat")
	return body.global_position + facing * float(profile.get("reach", 0.35)) + Vector3.UP * float(profile.get("height", 1.8)) * height_fraction
