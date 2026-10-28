class_name SplashImpact
extends ShotImpact

## Splash of a creature's shot: every live body whose hit box is within the radius of the burst takes
## amount·(1 − d/radius) as splash ranged damage. SplashDamage owns the walk.
##
## - Mutant babt / Abomination tugt: the body it hit takes the whole amount as ranged|splash (splash ranged resistance),
##   and the rest of damageRange the falloff: `direct_hit` on, `radius_source` DAMAGE_RANGE.
## - Flummox crba: nobody is hit whole, the body it hit included takes the falloff: `direct_hit` off,
##   `radius_source` EFFECT_RANGE.
## The side is Health's rule (Health._side_factor): the shooter's own side takes 0 or ally_damage_factor by the
## match's friendly fire, the shooter included if it stands in the radius.
## Ref: F139; sacengine dealSplashRangedDamageAt (state.d:9400) = dealDamageAt with DamageMod.splash|ranged, state.d:9055-9088, resistance 8952-8954, 9077, mutantProjectileExplosion 24381-24387, abominationProjectileExplosion 24432-24439, flummoxProjectileExplosion 24059-24067.

const _HEALTH := preload("res://scenes/components/health.gd")
const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

enum RadiusSource { DAMAGE_RANGE, EFFECT_RANGE }

## The body the shot hit takes the whole amount (splash ranged) and is left out of the falloff.
@export var direct_hit := true
## Which SPEL range is the splash radius.
@export var radius_source := RadiusSource.DAMAGE_RANGE


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var amount := float(shot.get("damage"))
	var from_slot := int(shot.get("from_slot"))
	var radius := _radius(ability)
	var mods := mods_of(shot)
	var shooter := shooter_of(shot)
	var direct := target if direct_hit and target and is_instance_valid(target) else null
	print("salpicadura %s en (%.1f, %.1f, %.1f) radio %.1f m de %d" % [ability.tag if ability else "?", point.x, point.y, point.z, radius, roundi(amount)])
	if direct and ProjectileTargets.is_live_body(direct):
		print("  directo %s" % GameBody.name_of(direct))
		_SPLASH.hurt(direct, amount, from_slot, _HEALTH.SPLASH_RANGED, mods, shooter)
	for body in _SPLASH.bodies_within(get_tree(), point, radius, direct):
		print("  %s a %.2f m" % [GameBody.name_of(body), _SPLASH.box_distance(body, point)])
	_SPLASH.deal(get_tree(), point, amount, radius, direct, from_slot, _HEALTH.SPLASH_RANGED, mods, shooter)


func _radius(ability: AbilityType) -> float:
	if ability == null:
		return 0.0
	return ability.effect_range_m if radius_source == RadiusSource.EFFECT_RANGE else ability.damage_range_m
