class_name ShotImpact
extends Node

## What a creature's ranged shot does where it bursts, in place of the plain direct hit. The scene
## is ShotLook.impact; RangedShot instances it on the server (or solo) only, as a child of the shot, calls apply() once
## and frees it with the shot. A shot whose ShotLook has no impact keeps the direct ranged hit (earthflingProjectileExplosion).
##
## Composition: apply() runs this node's _affect() and then apply() of every ShotImpact child, so one scene can splash
## and stun (Flummox, 030i) without a new script per pair. Variants override _affect().
## Ref: F119 (RFC-030h), sacengine earthflingProjectileExplosion.

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


## F155: the DamageMod bits the shot (or strike) `holder` carries; 0 when it has none.
static func mods_of(holder: Node) -> int:
	var value: Variant = holder.get("mods") if holder != null else null
	return int(value) if value != null else 0


## F164: the body that fired `holder` (a RangedShot or a ShotStrike), or null when it is gone or was never set.
static func shooter_of(holder: Node) -> Node:
	var path: Variant = holder.get("shooter_path") if holder != null else null
	if not path is NodePath or (path as NodePath).is_empty():
		return null
	return holder.get_node_or_null(path as NodePath)


static func who(body: Node) -> String:
	return str(body.call("display_name")) if body.has_method("display_name") else str(body.name)  # dynamic: unit, wizard and doctor bodies name themselves


## What a creature's shot or strike does where it lands: the ShotLook.impact scene (as a child of `holder`, freed with
## it), or without one the whole amount as direct ranged damage to the body hit;
## then the look's impact_fx at `point` on every
## peer. `holder`: the RangedShot or ShotStrike (damage and from_slot already scaled by the shooter). `target`: the body
## hit, or null (ground, range end). Server (or solo) only. Returns the damage the body took from the direct hit; 0 when
## it took none or an impact scene decided.
## Ref: sacengine earthflingProjectileExplosion state.d:23152-23154, gnomeShoot dealRangedDamage 11731.
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
	elif hit and preload("res://scenes/spells/rock_projectile.gd").is_live_body(hit):
		## Local preloads: the variants (SplashImpact, DirectImpact, …) already name theirs _HEALTH and _ROCK.
		var direct_ranged: StringName = preload("res://scenes/components/health.gd").DIRECT_RANGED
		taken = (hit.get_node("Health") as Health).damage_typed(float(holder.get("damage")), direct_ranged, int(holder.get("from_slot")), false, false, mods_of(holder))
		preload("res://scenes/spells/rock_projectile.gd").report(hit, taken, direct_ranged)  ## F155: the bench reads this line
		LifeDrain.feed(shooter_of(holder), hit, taken)  ## F164
	for fx: ParticleType in look.impact_fx:
		FxBus.broadcast(fx, point)
	ScarMark.broadcast(look.ground_mark, point)
	return taken
