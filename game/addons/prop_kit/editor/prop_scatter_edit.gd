@tool
extends RefCounted

## Editor only (loaded when used, never in a game): «Scatter» and «Clear» as actions of the editor's
## history, so Ctrl+Z puts back the props they replaced, hand edits and all. The old props are
## kept out of the tree, not freed, while the action can still be undone.


## Scatters `node` (a PropScatter3D / PropScatter2D) as one undoable action.
static func scatter(node: Node) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var before: Array[Node] = node.call(&"_take_props")
	var spots: Variant = node.call(&"_plan", root)
	if spots == null:
		node.call(&"_swap_props", [] as Array[Node], before, root)
		return
	var planted: int = node.call(&"_plant", spots, root)
	_commit(node, "Scatter %s" % node.name, before, node.get_children(), root)
	print("PropKit: %s planted %d props" % [node.name, planted])


## Clears `node` as one undoable action.
static func clear(node: Node) -> void:
	if node.get_child_count() == 0:
		return
	var root := EditorInterface.get_edited_scene_root()
	var before: Array[Node] = node.call(&"_take_props")
	_commit(node, "Clear %s" % node.name, before, [] as Array[Node], root)


## Scatters every PropScatter3D / PropScatter2D of the open scene, in tree order, each its own
## undoable action.
static func scatter_open_scene() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("PropKit: open a scene first")
		return
	var scatters: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		if node is PropScatter3D or node is PropScatter2D:
			scatters.append(node)
	for node in scatters:
		# A scatter inside another one's props went with them.
		if is_instance_valid(node) and node.is_inside_tree():
			scatter(node)


static func _commit(
	node: Node, action: String, before: Array[Node], after: Array[Node], root: Node
) -> void:
	var history := EditorInterface.get_editor_undo_redo()
	history.create_action(action, UndoRedo.MERGE_DISABLE, node)
	history.add_do_method(node, &"_swap_props", before, after, root)
	history.add_undo_method(node, &"_swap_props", after, before, root)
	for child in after:
		history.add_do_reference(child)
	for child in before:
		history.add_undo_reference(child)
	history.commit_action(false)
	# Zones nodes recheck their saved bake against the new props.
	for zones in root.find_children("*", "", true, false):
		if zones is PropNavZones3D or zones is PropNavZones2D:
			zones.update_configuration_warnings()
	if node is Node3D:
		(node as Node3D).update_gizmos()
