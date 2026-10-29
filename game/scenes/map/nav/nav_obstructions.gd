class_name NavObstructions
extends RefCounted

## The cheap blockers of the bake: each node of `GROUP` under the root (a forest tree) is a
## projected obstruction, an octagon around each CylinderShape3D child (its trunk, with the node's
## scale), added straight to the parsed source geometry, so thousands of trees cost the main thread
## next to nothing on every re-bake (parsing their colliders as geometry cost ~60 ms for 2000). The
## full bake (bake_nav) and the re-bakes (NavRebake) add the same; NavFingerprint hashes them.

const GROUP := &"nav_obstruction"
## Metadata key of the navmesh (bake_nav): how many obstructions the bake held. NavService bakes the
## map again when the match has a different count (a match without its forest).
const META_COUNT := &"obstructions"
const SIDES := 4


## Adds the obstructions of the `GROUP` nodes under `root` to `geometry`; returns how many. With
## `within` (map x, z) only the nodes inside one of those rects: a re-bake of a few zones needs no
## more.
static func add_to(
	geometry: NavigationMeshSourceGeometryData3D, root: Node, within: Array[Rect2] = []
) -> int:
	var count := 0
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if not (node is Node3D and (node == root or root.is_ancestor_of(node))):
			continue
		if not within.is_empty() and not _inside((node as Node3D).global_position, within):
			continue
		for child in node.get_children():
			var trunk := child as CollisionShape3D
			if trunk == null or trunk.disabled or not trunk.shape is CylinderShape3D:
				continue
			var cylinder := trunk.shape as CylinderShape3D
			var scale := trunk.global_transform.basis.get_scale()
			var radius := cylinder.radius * maxf(scale.x, scale.z)
			var height := cylinder.height * scale.y
			var at := trunk.global_position
			var outline := PackedVector3Array()
			for side in SIDES:
				var angle := TAU * side / SIDES
				outline.append(at + Vector3(cos(angle), 0.0, sin(angle)) * radius)
			geometry.add_projected_obstruction(outline, at.y - height * 0.5, height, false)
			count += 1
	return count


static func _inside(at: Vector3, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(Vector2(at.x, at.z)):
			return true
	return false


## How many `GROUP` nodes stand under `root` now.
static func count_in(root: Node) -> int:
	var count := 0
	for node in root.get_tree().get_nodes_in_group(GROUP):
		if node == root or root.is_ancestor_of(node):
			count += 1
	return count
