class_name ForestDraw
extends Node3D

## Draws the map's forest trees in play (FloraField owns it, an internal child): one
## MultiMeshInstance3D per mesh and per `chunk_m` square of the map, so thousands of trees are a
## few draws and the camera culls them by square. The tree nodes stay for the collision and the
## navmesh; their own Mesh is hidden while this draws them. Presentation only; never in the editor
## (there each tree shows its own mesh, to move it with the gizmo).

## Side of a culling square.
var chunk_m := 256.0

var _hidden: Array[MeshInstance3D] = []


## Draws `trees` (the forest_tree nodes) with `mesh_of` (tree → Mesh) and hides their own meshes.
## Called again it draws them anew (a new land).
func build(trees: Array[Node], mesh_of: Callable) -> void:
	clear()
	var batches := {}
	for tree: Node in trees:
		var part := tree.get_node_or_null(^"Mesh") as MeshInstance3D
		if part == null or not tree is Node3D:
			continue
		var mesh: Mesh = mesh_of.call(tree)
		if mesh == null:
			continue
		var at := (tree as Node3D).global_position
		var key := [mesh, floori(at.x / chunk_m), floori(at.z / chunk_m)]
		if not batches.has(key):
			batches[key] = []
		batches[key].append(part.global_transform)
		part.visible = false
		_hidden.append(part)
	for key: Array in batches:
		var transforms: Array = batches[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = key[0]
		multi.instance_count = transforms.size()
		for index in transforms.size():
			multi.set_instance_transform(index, transforms[index])
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(draw)


## Shows the trees' own meshes again and frees the batches.
func clear() -> void:
	for part in _hidden:
		if is_instance_valid(part):
			part.visible = true
	_hidden.clear()
	for child in get_children():
		child.queue_free()
