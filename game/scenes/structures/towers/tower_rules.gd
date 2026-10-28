class_name TowerRules
extends RefCounted

## Where a tower can go: the closest manafount (free, or any) and whether a building stands on its BuildArea. Pure questions over the
## tree: they change nothing. Creatures and wizards never block a tower: the cast pushes them out (BuildArea.push_bodies).
## Who casts and what appears is StructureAction and StructureSpawner.

## Bodies a tower cannot be dropped on.
const BLOCKERS: Array[StringName] = [MapBuilding.STRUCTURE_GROUP]
## Metres of free ground kept around the tower's footprint (where clear_footprint leaves the bodies it moves out).
const MARGIN_M := 2.0


## The fount closest to `point` within `max_distance` (only the free ones with `free_only`), or null.
static func closest_fount(tree: SceneTree, point: Vector3, max_distance: float, free_only := true) -> ManafountBody:
	var best: ManafountBody = null
	var best_d := INF
	for node in tree.get_nodes_in_group(ManafountBody.GROUP):
		var fount := node as ManafountBody
		if fount == null or not is_instance_valid(fount) or (free_only and not fount.is_free()):
			continue
		var d := fount.anchor().distance_to(point)
		if d <= max_distance and d < best_d:
			best_d = d
			best = fount
	return best


## True when no building stands within the radius of `area` (flat distance from its middle). No area: true.
static func has_room(tree: SceneTree, area: BuildArea) -> bool:
	if area == null:
		return true
	var middle := area.center()
	var radius := area.radius_m()
	for group in BLOCKERS:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or not is_instance_valid(body):
				continue
			if Vector2(body.global_position.x - middle.x, body.global_position.z - middle.z).length() <= radius:
				return false
	return true
