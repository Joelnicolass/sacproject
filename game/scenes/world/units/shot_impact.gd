class_name ShotImpact
extends Node

## F119 (RFC-030h): what a creature's ranged shot does where it bursts, in place of the plain direct hit. The scene
## is ShotLook.impact; RangedShot instances it on the server (or solo) only, as a child of the shot, calls apply() once
## and frees it with the shot. A shot whose ShotLook has no impact keeps the direct ranged hit (earthflingProjectileExplosion).
##
## Composition: apply() runs this node's _affect() and then apply() of every ShotImpact child, so one scene can splash
## and stun (Flummox, 030i) without a new script per pair. Variants override _affect().


## `shot`: the bursting RangedShot (damage and from_slot already scaled by the shooter). `target`: the body it hit, or
## null on the ground. `point`: where it burst. `ability`: the shot's SPEL (ranges), or null if GameData has no such tag.
func apply(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	_affect(shot, target, point, ability)
	for child in get_children():
		if child is ShotImpact:
			(child as ShotImpact).apply(shot, target, point, ability)


## What this impact does. Default: nothing.
func _affect(_shot: Node3D, _target: Node3D, _point: Vector3, _ability: AbilityType) -> void:
	pass


static func who(body: Node) -> String:
	return str(body.call("display_name")) if body.has_method("display_name") else str(body.name)
