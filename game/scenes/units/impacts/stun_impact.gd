class_name StunImpact
extends ShotImpact

## F120 (RFC-030i-a): the Flummox's stun. flummoxProjectileExplosion (state.d:24059-24067) passes a callback to
## dealSplashRangedDamageAt that calls stunWithCooldown(target, 480) on every moving body whose box is within
## effectRange of the burst, before its damage: no side filter, the shooter included (dealDamageAt skips only the
## direct target, which is 0 here, 9075-9089). The walk is SplashDamage's; each body's Afflictions/Stunned decides.
## Wizards too (F138, RFC-030i-c: wizard_body.tscn has Afflictions/Stunned). A body with no Stunned is named in the log.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")
const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

## sacengine stunCooldownFrames = 8·updateFPS.
@export var cooldown_ticks := 480
## sacengine movingObjects: creatures and wizards (buildings are not stunned).
@export var groups: Array[StringName] = [&"wizard", &"unit"]
## The path of the Stunned state under each body.
@export var stunned_path := NodePath("Afflictions/Stunned")
## F161 (RFC-030 030w-b): stun only the body the shot hit, not the bodies around the burst. The Brainiac's bsba and the
## Shrike's absh (updateBrainiacProjectile 22924-22929, updateShrikeProjectile 22978-22983) call stunWithCooldown on
## the creature or wizard they strike, then goto dealRangedDamage; a building takes the damage only, the ground nothing.
## Off: the walk of radius effect_range around the burst (the Flummox, F120).
@export var target_only := false


func _affect(_shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if target_only:
		if _is_stunnable(target):
			_stun(target)
		return
	var radius := ability.effect_range if ability else 0.0
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		_stun(body)


## A creature or a wizard (a building and the ground are not stunned).
func _is_stunnable(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not _ROCK.is_live_body(body):
		return false
	for group in groups:
		if body.is_in_group(group):
			return true
	return false


func _stun(body: Node3D) -> void:
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stunned == null:
		print("  aturdir: %s no tiene Stunned" % who(body))
	elif not stunned.stun_with_cooldown(cooldown_ticks) and stunned.cooldown_ticks() > 0:
		print("  aturdir: %s en enfriamiento (%d) (cuadro %d)" % [who(body), stunned.cooldown_ticks(), MatchClock.now()])
