class_name SplashImpact
extends ShotImpact

## Splash of a creature's shot: sacengine dealSplashRangedDamageAt (state.d:9400) = dealDamageAt with
## DamageMod.splash|ranged: every live body whose hit box is within the radius of the burst takes
## amount·(1 − d/radius) as splash ranged damage (state.d:9055-9088, resistance pick 8952-8954). SplashDamage owns the walk.
##
## - Mutant babt / Abomination tugt (mutantProjectileExplosion state.d:24381-24387, abominationProjectileExplosion
##   24432-24439): the body it hit takes the whole amount as ranged|splash (splash ranged resistance), and the rest
##   of damageRange the falloff: `direct_hit` on, `radius_source` DAMAGE_RANGE.
## - Flummox crba (flummoxProjectileExplosion 24059-24067): dealSplashRangedDamageAt(0, …, effectRange): nobody is
##   hit whole, the body it hit included takes the falloff: `direct_hit` off, `radius_source` EFFECT_RANGE.
## The side is Health's rule (Health._side_factor, F139): the shooter's own side takes 0 or ally_damage_factor by the
## match's friendly fire, the shooter included if it stands in the radius (state.d:9077).

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

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
	var direct := target if direct_hit and target and is_instance_valid(target) else null
	print("salpicadura %s en (%.1f, %.1f, %.1f) radio %.1f m de %d" % [ability.tag if ability else "?", point.x, point.y, point.z, radius, roundi(amount)])
	if direct and _ROCK.is_live_body(direct):
		print("  directo %s" % who(direct))
		_SPLASH.hurt(direct, amount, from_slot, _HEALTH.SPLASH_RANGED, mods)
	for body in _SPLASH.bodies_within(get_tree(), point, radius, direct):
		print("  %s a %.2f m" % [who(body), _SPLASH.box_distance(body, point)])
	_SPLASH.deal(get_tree(), point, amount, radius, direct, from_slot, _HEALTH.SPLASH_RANGED, mods)


func _radius(ability: AbilityType) -> float:
	if ability == null:
		return 0.0
	return ability.effect_range if radius_source == RadiusSource.EFFECT_RANGE else ability.damage_range
