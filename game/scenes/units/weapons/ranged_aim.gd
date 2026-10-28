class_name RangedAim
extends RefCounted

## The decisions of a ranged weapon before it shoots: whether this foe is for shooting or for striking, and, once the foe is in
## range with a clear line, whether the body already faces the aim and the weapon is loaded. Not: the shot itself (RangedFire).
## Ref: sacengine `attack` (state.d:12849-12855), `aim` (state.d:12521-12571), shootRange (state.d:12468).


## Shoot unless the foe is in melee contact. A body of the weapon's own side (a Scarab's patient) is always shot, never struck.
static func wants(weapon: RangedWeapon, target: Node3D) -> bool:
	var body := weapon.body
	if weapon.attack == null or target == null or body.afflictions.raging():
		return false
	if "owner_slot" in target and int(target.get("owner_slot")) == body.owner_slot:
		return true
	var melee := weapon.weapons.melee
	if melee == null or not melee.in_reach(target, melee.start_factor):
		return true
	return ShotAim.box_gap(body, target) > weapon.melee_distance


## It stops to shoot at max(range_factor·range, range − range_margin) from the body to the target's box.
static func reach(weapon: RangedWeapon) -> float:
	var attack := weapon.attack
	if attack == null:
		return 0.0
	return maxf(weapon.range_factor * attack.cast_range_m, attack.cast_range_m - weapon.range_margin)


## APPROACH out of range or without a clear line, HOLD while it turns or reloads, FIRE once it can start the shot.
static func step(weapon: RangedWeapon, target: Node3D) -> Weapon.Step:
	var body := weapon.body
	if body.global_position.distance_to(ShotAim.box_point(body, target)) > reach(weapon):
		return Weapon.Step.APPROACH
	var led := weapon.predicted(target)
	if not ShotAim.clear_shot(body, target, weapon.shot_origin(), led, weapon.clear_shot_drop, weapon.ground_mask):
		return Weapon.Step.APPROACH
	var to := led - body.global_position
	to.y = 0.0
	var facing: Vector3 = body.facing_flat()
	if to.length_squared() > 0.000001 and facing.angle_to(to.normalized()) > float(MatchClock.ticks_for(weapon.facing_s)) * body.locomotion.turn_rate / MatchClock.TICKS_PER_SECOND_F:
		return Weapon.Step.HOLD
	return Weapon.Step.FIRE if RangedFire.loaded(weapon) else Weapon.Step.HOLD


## Flat direction the body should face to shoot `target`.
static func direction(weapon: RangedWeapon, target: Node3D) -> Vector3:
	var to := weapon.predicted(target) - weapon.body.global_position
	to.y = 0.0
	return to.normalized() if to.length_squared() > 0.000001 else weapon.body.facing_flat()
