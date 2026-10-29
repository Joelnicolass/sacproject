@tool
extends EditorPlugin

## Project > Tools: "PropKit: Scatter the open scene" runs every PropScatter3D and PropScatter2D of
## the scene being edited, in tree order, each undoable (the same as pressing «Scatter» on each).
## "PropKit: Bake the open scene" saves it and bakes every zones node in it (the same as «Bake»).
## In the 3D view: the scatters' ground outlines and the zones' grids.

const SCATTER_MENU := "PropKit: Scatter the open scene"
const BAKE_MENU := "PropKit: Bake the open scene"

var _gizmos: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	add_tool_menu_item(SCATTER_MENU, _on_scatter_all)
	add_tool_menu_item(BAKE_MENU, _on_bake_all)
	_gizmos = preload("editor/prop_gizmos.gd").new()
	add_node_3d_gizmo_plugin(_gizmos)


func _exit_tree() -> void:
	remove_tool_menu_item(SCATTER_MENU)
	remove_tool_menu_item(BAKE_MENU)
	remove_node_3d_gizmo_plugin(_gizmos)


func _on_scatter_all() -> void:
	preload("editor/prop_scatter_edit.gd").scatter_open_scene()


func _on_bake_all() -> void:
	preload("editor/prop_bake_run.gd").bake_open_scene()
