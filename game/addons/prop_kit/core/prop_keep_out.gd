@tool
class_name PropKeepOut
extends Resource

## Props stay away from the nodes of a group: none within `radius`, then fewer and smaller up to
## `radius * (1 + soft)`. The game names the group (its spawn points, buildings, road markers...);
## the kit never knows their classes. A node of the group counts by its position on the ground
## plane: (x, z) for a Node3D, (x, y) for a Node2D.

@export var group: StringName
## No prop closer than this (world units).
@export_range(0.0, 10000.0, 0.1, "or_greater") var radius := 10.0
## The soft edge past `radius`, as a part of it (0.4 = 40 % more, thinning out).
@export_range(0.0, 4.0, 0.01) var soft := 0.4


## The discs of `keep_outs` around the nodes of their groups under `root` but not under `skip` (the
## scatter's own props): x, y = the point on the ground plane, z = radius, w = soft.
static func discs(keep_outs: Array[PropKeepOut], root: Node, skip: Node) -> PackedVector4Array:
	var out := PackedVector4Array()
	if root == null or not root.is_inside_tree():
		return out
	for keep_out in keep_outs:
		if keep_out == null or keep_out.group.is_empty():
			continue
		for node in root.get_tree().get_nodes_in_group(keep_out.group):
			if node != root and not root.is_ancestor_of(node):
				continue
			if skip != null and (node == skip or skip.is_ancestor_of(node)):
				continue
			var at := Vector2.INF
			if node is Node3D:
				var p := (node as Node3D).global_position
				at = Vector2(p.x, p.z)
			elif node is Node2D:
				at = (node as Node2D).global_position
			if at != Vector2.INF:
				out.append(Vector4(at.x, at.y, keep_out.radius, keep_out.soft))
	return out
