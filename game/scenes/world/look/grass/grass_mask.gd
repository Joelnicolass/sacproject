class_name GrassMask
extends RefCounted

## Where the grass does not grow: the clearings. Gathers every `VegetationClear` node and the
## default clearings of the `GrassSet` (altar and fountain groups) into the array the shader reads,
## in map coordinates (the grass layer's local space). The layer weights, slope and path rules are
## not here: the shader evaluates them with the ground's own rules (`ground_common.gdshaderinc`),
## so the grass follows the ground exactly. Nothing built here is saved.

const MAX_CLEARS := 48
const ALTAR_GROUP := &"altar"
const FOUNT_GROUP := &"manafount"

## Rows: x, z (map), radius, edge.
var clears := PackedVector4Array()


## Rebuilds `clears`; returns true when they changed.
func gather(tree: SceneTree, space: Node3D, grass_set: GrassSet) -> bool:
	var found := PackedVector4Array()
	if tree == null:
		return _store(found)
	for node in tree.get_nodes_in_group(VegetationClear.GROUP):
		var clear := node as VegetationClear
		if clear and clear.is_inside_tree() and clear.radius_m > 0.0:
			_add(found, space, clear.global_position, clear.radius_m, clear.edge_m)
	if grass_set:
		_add_group(found, tree, space, ALTAR_GROUP, grass_set.altar_clear_m, grass_set.altar_edge_m)
		_add_group(found, tree, space, FOUNT_GROUP, grass_set.fount_clear_m, grass_set.fount_edge_m)
	return _store(found)


func _add_group(found: PackedVector4Array, tree: SceneTree, space: Node3D, group: StringName, radius: float, edge: float) -> void:
	if radius <= 0.0:
		return
	for node in tree.get_nodes_in_group(group):
		var spot := node as Node3D
		if spot and spot.is_inside_tree():
			_add(found, space, spot.global_position, radius, edge)


func _add(found: PackedVector4Array, space: Node3D, world_position: Vector3, radius: float, edge: float) -> void:
	if found.size() >= MAX_CLEARS:
		return
	var local := space.to_local(world_position)
	found.append(Vector4(local.x, local.z, radius, edge))


func _store(found: PackedVector4Array) -> bool:
	if found == clears:
		return false
	clears = found
	return true


## The array padded to the uniform's size.
func padded() -> PackedVector4Array:
	var out := clears.duplicate()
	out.resize(MAX_CLEARS)
	return out
