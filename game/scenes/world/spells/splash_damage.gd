class_name SplashDamage
extends RefCounted

## sacengine dealSplashSpellDamageAt / dealDamageAt (state.d:9063-9095): every live wizard, creature
## and building within `radius` of the burst takes amount·(1 − d/radius) as splash spell damage, d being
## the distance from the point to its hit box. The side is not filtered here (Health refuses damage to
## its own slot); a body with no health (maximum ≤ 0, sacengine canDamage) is skipped. Used by Wrath,
## Fireball and Swarm (RFC-028b). Wizards and creatures go first, in the order of their groups, so the
## damage they take is the same as before buildings joined.

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

const GROUPS: Array[StringName] = [&"wizard", &"unit", &"structure"]


## Hurts every body around `center` except `direct` (which the caller already hit with the whole amount).
static func deal(tree: SceneTree, center: Vector3, amount: float, radius: float, direct: Node3D, from_slot: int) -> void:
	if radius <= 0.0:
		return
	var seen := {}
	for group in GROUPS:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == direct or seen.has(body) or not _ROCK.is_live_body(body):
				continue
			seen[body] = true
			var health := body.get_node("Health")
			if float(health.get("maximum")) <= 0.0:
				continue
			var distance := box_distance(body, center)
			if distance <= radius:
				hurt(body, amount * maxf(0.0, 1.0 - distance / radius), from_slot)


static func hurt(body: Node3D, amount: float, from_slot: int) -> void:
	var taken := float(body.get_node("Health").call("damage_typed", amount, _HEALTH.SPLASH_SPELL, from_slot))
	_ROCK.report(body, taken, _HEALTH.SPLASH_SPELL)


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
