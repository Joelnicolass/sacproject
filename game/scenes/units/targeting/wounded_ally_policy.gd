class_name WoundedAllyPolicy
extends TargetPolicy

## The Scarab (slba, Healing web): by itself it takes the
## creature of its own side with the lowest relative health that is not full (lowestHealthCreatureInRange:
## a moving object, not itself, valid), first within its ranged attack's range of the center and then within its sight;
## it never picks a foe. Under an ATTACK order it keeps the foe it was told to attack, as any creature (attack).
## A wounded ally stays a valid target until its bar is full, then the body drops it and stops shooting.
## Ref: F136 (RFC-030h2), sacengine updateTarget state.d:12949-12958, lowestHealthCreatureInRange 28828-28842, attack 12849-12855.

const _HEAL := preload("res://scenes/spells/heal_effect.gd")

## Groups of the bodies it may heal: wizards and creatures (movingObjects).
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func accepts(body: UnitBody, node: Variant, explicit: bool) -> bool:
	if explicit and super.accepts(body, node, explicit):
		return true
	return is_patient(body, node)


func pick(body: UnitBody, center: Vector3, within: float) -> Node3D:
	var shot: AbilityType = body.type.ranged_attack if body.type else null
	var reach := shot.cast_range_m if shot else 0.0
	var found := _most_wounded(body, center, minf(reach, within))
	if found == null:
		found = _most_wounded(body, center, minf(body.vision.range_m(), within))
	return found


## A live, targetable body of `body`'s side (not itself) whose health is not full (canHeal).
func is_patient(body: UnitBody, node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or node == body or not node is Node3D:
		return false
	var other := node as Node3D
	if not other.is_inside_tree() or other.is_in_group(Corpse.GROUP) or not "owner_slot" in other:
		return false
	if int(other.get("owner_slot")) != body.owner_slot or not _in_groups(other):
		return false
	if other is UnitBody and (other as UnitBody).is_summoning():
		return false
	if other is UnitBody and (other as UnitBody).is_rock_form():
		return false
	if not GameBody.targetable(other):
		return false
	return _HEAL.can_heal(other)


## The patient of the lowest current/maximum within `radius` of `center` (flat); ties go to the closer one.
func _most_wounded(body: UnitBody, center: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_ratio := INF
	var best_distance := INF
	if radius <= 0.0:
		return null
	for group in groups:
		for node in body.get_tree().get_nodes_in_group(group):
			if not is_patient(body, node):
				continue
			var other := node as Node3D
			var distance := Vector2(other.global_position.x - center.x, other.global_position.z - center.z).length()
			if distance > radius:
				continue
			var health := other.get_node("Health")
			var maximum := float(health.get("maximum"))
			var ratio := float(health.get("current")) / maximum if maximum > 0.0 else INF
			if ratio < best_ratio or (ratio == best_ratio and distance < best_distance):
				best = other
				best_ratio = ratio
				best_distance = distance
	return best


func _in_groups(node: Node) -> bool:
	for group in groups:
		if node.is_in_group(group):
			return true
	return false
