class_name DeathCloud
extends Node3D

## The cloud a creature leaves when it dies. The original adds one
## SteamCloud / PoisonCloud / HealingShower effect that acts once, on its first update, and is gone;
## what lasts is on the bodies it touched (a Poisoned dose, a HealEffect). So does this node: burst() acts
## on the bodies around the dead one's center, plays its puff through FxBus (clients see it there) and frees itself.
## Server (or solo) only. The variants override _affect(); the numbers come from the SPEL of `ability`.
## Ref: F118 (RFC-030g), sacengine kill() state.d:8274-8278, state.d:25216-25254, 25674-25697.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

## Bodies a cloud may touch: creatures and wizards (movingObjects). SteamCloud also hits buildings itself.
const GROUPS: Array[StringName] = [&"wizard", &"unit"]

## The numbers of the cloud (DeathCloudType.ability); set by DeathCloudSpawner before burst().
var ability: AbilityType
## The dead body's slot.
var from_slot := 0
## The dead body: never touched by its own cloud (dealDamageAt directTarget).
## Ref: sacengine state.d:25239.
var dead: Node3D


## Acts once around `center` (the dead body's box center), plays `fx` there and frees the node.
func burst(center: Vector3, fx: ParticleType) -> void:
	global_position = center
	var dead_name := who(dead) if dead else "?"
	print("nube %s de %s (slot %d) en (%.1f, %.1f, %.1f)" % [ability.tag if ability else "?", dead_name, from_slot, center.x, center.y, center.z])
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


static func who(body: Node) -> String:
	return str(body.call("display_name")) if body.has_method("display_name") else str(body.name)  # dynamic: unit, wizard and doctor bodies name themselves
