class_name SplashDamage
extends RefCounted

## sacengine dealSplashSpellDamageAt / dealDamageAt (state.d:9063-9095): every live wizard, creature
## and building within `radius` of the burst takes amount·(1 − d/radius) as splash spell damage, d being
## the distance from the point to its hit box. The side is not filtered here: the rule of the side lives in Health
## (Health._side_factor: an ally takes 0 or ally_damage_factor by the match's friendly fire, F139), and the attacker
## stands in its own radius like any body (dealDamageAt skips only the directTarget, state.d:9077). A body with no
## health (maximum ≤ 0, sacengine canDamage) is skipped. Used by Wrath,
## Fireball and Swarm (RFC-028b). Wizards and creatures go first, in the order of their groups, so the
## damage they take is the same as before buildings joined.

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

const GROUPS: Array[StringName] = [&"wizard", &"unit", &"structure"]


## Hurts every body around `center` except `direct` (which the caller already hit with the whole amount).
## `kind` is the Health damage kind: splash spell (Wrath, Fireball, Swarm, Steam Cloud) or splash ranged
## (dealSplashRangedDamageAt, state.d:9400: a creature's shot, F119). `mods`: the DamageMod bits (F155: IGNITE).
static func deal(tree: SceneTree, center: Vector3, amount: float, radius: float, direct: Node3D, from_slot: int, kind: StringName = _HEALTH.SPLASH_SPELL, mods := 0, attacker: Node = null) -> void:
	for body in bodies_within(tree, center, radius, direct):
		if float(body.get_node("Health").get("maximum")) <= 0.0:
			continue
		hurt(body, amount * maxf(0.0, 1.0 - box_distance(body, center) / radius), from_slot, kind, mods, attacker)


## The one walk of a splash (sacengine dealDamageAt's collisionTargets, state.d:9075-9088): live bodies of `groups`
## whose hit box is within `radius` of `center`, but `except`, in group order (so the result does not depend on the
## scene tree). Wizards and creatures go first. DeathCloud asks with creatures and wizards only.
static func bodies_within(tree: SceneTree, center: Vector3, radius: float, except: Node3D = null, groups: Array[StringName] = GROUPS) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if radius <= 0.0:
		return found
	var seen := {}
	for group in groups:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == except or seen.has(body) or not _ROCK.is_live_body(body):
				continue
			seen[body] = true
			if box_distance(body, center) <= radius:
				found.append(body)
	return found


## `mods` (F155): the DamageMod bits the hit carries (Health.IGNITE: Fireball, Steam Cloud, fkba/cfba shots, the oil's blast).
## F164b: `attacker` is the creature that fired the shot (null: a spell or an effect with no drain); LifeDrain.feed gives it
## back `taken · its drain` (sacengine dealDamage with an attacker creature, state.d:8933-8947, also on the splash walk).
static func hurt(body: Node3D, amount: float, from_slot: int, kind: StringName = _HEALTH.SPLASH_SPELL, mods := 0, attacker: Node = null) -> void:
	var taken := float(body.get_node("Health").call("damage_typed", amount, kind, from_slot, false, false, mods))
	_ROCK.report(body, taken, kind)
	LifeDrain.feed(attacker, body, taken)


## sacengine boxPointDistance: from the point to the body's hit box. A map building gives its model box
## (`hit_box()`, before the collision inset), measured in the building's own frame: decision of the port,
## the original measures against a world AABB, so a turned house keeps its corners here. A capsule
## (creatures, wizards) is its axis-aligned box; a cylinder (placed structures) too.
static func box_distance(body: Node3D, point: Vector3) -> float:
	if body.has_method("hit_box"):
		var box: AABB = body.call("hit_box")
		return _outside(body.global_transform.affine_inverse() * point - (box.position + box.size * 0.5), box.size * 0.5)
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col == null or col.shape == null:
		return body.global_position.distance_to(point)
	var half := Vector3(0.3, 0.9, 0.3)
	var local := point - col.global_position
	if col.shape is CapsuleShape3D:
		var capsule := col.shape as CapsuleShape3D
		half = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
	elif col.shape is CylinderShape3D:
		var cylinder := col.shape as CylinderShape3D
		half = Vector3(cylinder.radius, cylinder.height * 0.5, cylinder.radius)
	elif col.shape is BoxShape3D:
		half = (col.shape as BoxShape3D).size * 0.5
		local = col.global_transform.affine_inverse() * point
	return _outside(local, half)


static func _outside(local: Vector3, half: Vector3) -> float:
	var outside := Vector3(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0), maxf(absf(local.z) - half.z, 0.0))
	return outside.length()
