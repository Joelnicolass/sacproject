class_name RagePolicy
extends TargetPolicy

## Blind Rage: while it lasts a creature fights the closest creature of any side, its own included (not itself), and keeps whatever it
## is fighting if it is still such a creature. It does not pick for a body that is not enraged (TargetPicker asks it only then) and it
## does not stop the orders (UnitOrders ignores them).

## Groups of the bodies it may fight: creatures and wizards.
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func accepts(body: UnitBody, node: Variant, _explicit: bool) -> bool:
	return TargetRules.is_valid_foe_of(-1, node, body, false) and _in_groups(node as Node)


func pick(body: UnitBody, center: Vector3, within: float) -> Node3D:
	var radius := minf(body.vision.range_m(), within)
	var best: Node3D = null
	var best_d := radius
	for group in groups:
		for node in body.get_tree().get_nodes_in_group(group):
			if not TargetRules.is_valid_foe_of(-1, node, body, false):
				continue
			var other := node as Node3D
			var d := (
				Vector2(other.global_position.x - center.x, other.global_position.z - center.z)
				. length()
			)
			if d <= best_d:
				best_d = d
				best = other
	return best


func _in_groups(node: Node) -> bool:
	if node == null:
		return false
	for group in groups:
		if node.is_in_group(group):
			return true
	return false
