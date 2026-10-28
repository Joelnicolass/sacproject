class_name ShotAim
extends RefCounted

## Where a creature's shot starts and where it goes: the origin, the target's centre and box, the
## point to lead, the clear line and the scatter of the ranged accuracy (the one owner of it:
## RangedFire draws it once per shot; a RayStrike that rerolls, the Warmonger's, draws it again for
## every ray). Not: when to shoot (RangedWeapon).


## The scatter of a shot: angle = atan(accuracy·0.001·0.14 + 0.03), azimuth angle·r³ and elevation
## 0.1·angle·r³ with r uniform in [−1, 1], azimuth drawn first. The order of the draws is the
## simulation's: do not swap them.
static func scatter(direction: Vector3, accuracy: float, rng: RandomNumberGenerator) -> Vector3:
	var angle := atan(accuracy * 0.001 * 0.14 + 0.03)
	var azimuth_roll := rng.randf_range(-1.0, 1.0)
	var elevation_roll := rng.randf_range(-1.0, 1.0)
	var azimuth := angle * azimuth_roll * azimuth_roll * azimuth_roll
	var elevation := 0.1 * angle * elevation_roll * elevation_roll * elevation_roll
	return direction.rotated(Vector3.RIGHT, elevation).rotated(Vector3.UP, azimuth)


## Where a shot leaves a body: its front (melee_profile reach along facing_flat) at
## `height_fraction` of its height. The one owner of the origin: RangedWeapon.shot_origin (its
## shot_height) and LobAbility (its own).
static func origin(body: UnitBody, height_fraction: float) -> Vector3:
	var profile := body.melee_profile()
	var facing := body.facing_flat()
	return (
		body.global_position
		+ facing * float(profile.get("reach", 0.35))
		+ Vector3.UP * float(profile.get("height", 1.8)) * height_fraction
	)


## The shot origin of `unit`'s ranged weapon, or its feet lifted when it has none. Breath of life
## and Devour (the soul shrinks toward it) both ask it.
static func shot_position(unit: Node3D) -> Vector3:
	var shooter := unit as UnitBody
	if shooter != null and shooter.weapons.ranged != null:
		return shooter.weapons.ranged.shot_origin()
	return unit.global_position + Vector3.UP * 1.8


## A body's centre: its Collision shape, else half its height over its feet.
static func center(target: Node3D) -> Vector3:
	var col := target.get_node_or_null("Collision") as Node3D
	return (
		col.global_position
		if col
		else (
			target.global_position
			+ Vector3.UP * float(MeleeRules.profile_of(target).get("height", 1.8)) * 0.5
		)
	)


## The target's centre where it will be when a shot of `speed` arrives.
static func predicted(body: Node3D, target: Node3D, speed: float) -> Vector3:
	var at := center(target)
	if speed <= 0.0 or not target is CharacterBody3D:
		return at
	var flight := body.global_position.distance_to(at) / speed
	var moving := (target as CharacterBody3D).velocity
	moving.y = 0.0
	return at + moving * flight


## The target's box point nearest to our centre.
static func box_point(body: Node3D, target: Node3D) -> Vector3:
	var at := center(target)
	var reach := float(MeleeRules.profile_of(target).get("reach", 0.35))
	var toward := body.global_position - at
	toward.y = 0.0
	if toward.length() <= reach:
		return at
	return at + toward.normalized() * reach


## The flat distance between the two boxes, 0 when they touch.
static func box_gap(body: UnitBody, target: Node3D) -> float:
	var d := target.global_position - body.global_position
	var own := float(body.melee_profile().get("reach", 0.35))
	return maxf(
		0.0,
		Vector2(d.x, d.z).length() - own - float(MeleeRules.profile_of(target).get("reach", 0.35))
	)


## Nothing of the ground mask between `from` and `to`, the line checked `drop` under both ends.
static func clear_shot(
	body: Node3D, target: Node3D, from: Vector3, to: Vector3, drop: float, mask: int
) -> bool:
	var down := Vector3.DOWN * drop
	var query := PhysicsRayQueryParameters3D.create(from + down, to + down)
	query.collision_mask = mask
	var skip: Array[RID] = []
	for node: Node in [body, target]:
		if node is CollisionObject3D:
			skip.append((node as CollisionObject3D).get_rid())
	query.exclude = skip
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
