class_name DeathCloud
extends Node3D

## The cloud a creature leaves when it dies: a
## SteamCloud / PoisonCloud / HealingShower effect that acts once, on its first update, and is gone;
## what lasts is on the bodies it touched (a Poisoned dose, a HealEffect). So does this node: burst() acts
## on the bodies around the dead one's center, plays its puff through FxBus (clients see it there) and frees itself.
## Server (or solo) only. The variants override _affect(); the numbers come from the SPEL of `ability`.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## Bodies a cloud may touch: creatures and wizards. SteamCloud also hits buildings itself.
const GROUPS: Array[StringName] = [WizardBody.GROUP, UnitBody.GROUP]

## The numbers of the cloud (DeathCloudType.ability); set by DeathCloudSpawner before burst().
var ability: AbilityType
## The dead body's slot.
var from_slot := 0
## The dead body: never touched by its own cloud.
var dead: Node3D


## Acts once around `center` (the dead body's box center), plays `fx` there and frees the node.
func burst(center: Vector3, fx: ParticleType) -> void:
	global_position = center
	var dead_name := GameBody.name_of(dead) if dead else "?"
	print("cloud %s of %s (slot %d) at (%.1f, %.1f, %.1f)" % [ability.tag if ability else "?", dead_name, from_slot, center.x, center.y, center.z])
	if ability:
		_affect(center)
	if fx != null:
		FxBus.broadcast(fx, center)
	queue_free()


## What the variant does. Default: nothing.
func _affect(_center: Vector3) -> void:
	pass


## Live creatures and wizards whose hit box is within `radius` of `center`, but the dead one (SplashDamage owns the walk).
func bodies_within(center: Vector3, radius: float) -> Array[Node3D]:
	return _SPLASH.bodies_within(get_tree(), center, radius, dead, GROUPS)
