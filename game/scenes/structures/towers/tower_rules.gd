class_name TowerRules
extends RefCounted

## Where a tower can go: the closest free manafount and whether a body stands in the way. Pure questions over the tree:
## they change nothing. Who casts and what appears is StructureAction and StructureSpawner.

## Bodies a tower cannot be dropped on.
const BLOCKERS: Array[StringName] = [&"wizard", &"unit", &"structure"]
## Metres of free ground kept around the tower's footprint.
const MARGIN_M := 2.0


## The free fount closest to `point` within `max_distance`, or null.
static func closest_free_fount(tree: SceneTree, point: Vector3, max_distance: float) -> ManafountBody:
	var best: ManafountBody = null
	var best_d := INF
	for node in tree.get_nodes_in_group(ManafountBody.GROUP):
		var fount := node as ManafountBody
		if fount == null or not is_instance_valid(fount) or not fount.is_free():
			continue
		var d := fount.anchor().distance_to(point)
		if d <= max_distance and d < best_d:
			best_d = d
			best = fount
	return best


## True when no wizard, creature or building is within the footprint plus the margin of `point`.
static func has_room(tree: SceneTree, point: Vector3, footprint_m: float) -> bool:
	for group in BLOCKERS:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body != null and is_instance_valid(body) and body.global_position.distance_to(point) <= footprint_m + MARGIN_M:
				return false
	return true
