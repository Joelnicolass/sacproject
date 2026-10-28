class_name StunImpact
extends ShotImpact

## The Flummox's stun. It stuns (480 ticks of cooldown) every moving body whose box is within
## effect range of the burst, before its damage: no side filter, the shooter included (only the
## direct target is skipped, and it is 0 here). The walk is SplashDamage's; each body's Afflictions/Stunned decides.
## Wizards too (wizard_body.tscn has Afflictions/Stunned). A body with no Stunned is named in the log.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## How long a stunned body cannot be stunned again.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var cooldown_s := 8.0
## Moving bodies: creatures and wizards (buildings are not stunned).
@export var groups: Array[StringName] = [&"wizard", &"unit"]
## The path of the Stunned state under each body.
@export var stunned_path := NodePath("Afflictions/Stunned")
## Stun only the body the shot hit, not the bodies around the burst. The Brainiac's bsba and the
## Shrike's absh stun the creature or wizard they strike, then deal the ranged damage; a building takes the damage only, the ground nothing.
## Off: the walk of radius effect_range around the burst (the Flummox).
@export var target_only := false


func _affect(_shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	if target_only:
		if _is_stunnable(target):
			_stun(target)
		return
	var radius := ability.effect_range_m if ability else 0.0
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		_stun(body)


## A creature or a wizard (a building and the ground are not stunned).
func _is_stunnable(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not ProjectileTargets.is_live_body(body):
		return false
	for group in groups:
		if body.is_in_group(group):
			return true
	return false


func _stun(body: Node3D) -> void:
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stunned == null:
		print("  stun: %s has no Stunned" % GameBody.name_of(body))
	elif not stunned.stun_with_cooldown(MatchClock.ticks_for(cooldown_s)) and stunned.cooldown_ticks() > 0:
		print("  stun: %s on cooldown (%d) (frame %d)" % [GameBody.name_of(body), stunned.cooldown_ticks(), MatchClock.now()])
