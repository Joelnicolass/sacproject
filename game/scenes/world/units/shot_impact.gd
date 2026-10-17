class_name ShotImpact
extends Node

## F119 (RFC-030h): what a creature's ranged shot does where it bursts, in place of the plain direct hit. The scene
## is ShotLook.impact; RangedShot instances it on the server (or solo) only, as a child of the shot, calls apply() once
## and frees it with the shot. A shot whose ShotLook has no impact keeps the direct ranged hit (earthflingProjectileExplosion).
##
## Composition: apply() runs this node's _affect() and then apply() of every ShotImpact child, so one scene can splash
## and stun (Flummox, 030i) without a new script per pair. Variants override _affect().

## F124: land() is the one owner of what a shot or a strike does where it lands (RangedShot._burst, ShotStrike._land).


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


## What a creature's shot or strike does where it lands: the ShotLook.impact scene (as a child of `holder`, freed with
## it), or without one the whole amount as direct ranged damage to the body hit (earthflingProjectileExplosion,
## state.d:23152-23154; gnomeShoot dealRangedDamage DamageMod.none, 11731); then the look's impact_fx at `point` on every
## peer. `holder`: the RangedShot or ShotStrike (damage and from_slot already scaled by the shooter). `target`: the body
## hit, or null (ground, range end). Server (or solo) only. Returns the damage the body took from the direct hit; 0 when
## it took none or an impact scene decided.
static func land(holder: Node3D, look: ShotLook, target: Node3D, point: Vector3, ability: AbilityType) -> float:
	var hit := target if target != null and is_instance_valid(target) else null
	var taken := 0.0
	if look.impact:
		var node := look.impact.instantiate()
		var impact := node as ShotImpact
		if impact:
			holder.add_child(impact)
			impact.apply(holder, hit, point, ability)
		else:
			node.free()
			push_warning("ShotImpact.land: el impacto de %s no es un ShotImpact." % holder.name)
	elif hit and preload("res://scenes/world/spells/rock_projectile.gd").is_live_body(hit):
		## Local preloads: the variants (SplashImpact, DirectImpact, …) already name theirs _HEALTH and _ROCK.
		var direct_ranged: StringName = preload("res://scenes/world/components/health.gd").DIRECT_RANGED
		taken = float(hit.get_node("Health").call("damage_typed", float(holder.get("damage")), direct_ranged, int(holder.get("from_slot"))))
	for fx in look.impact_fx:
		FxBus.broadcast(fx, point)
	return taken
