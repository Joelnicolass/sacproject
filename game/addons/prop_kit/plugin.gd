@tool
extends EditorPlugin

## Project > Tools > "PropKit: Scatter the open scene" runs every PropScatter3D and PropScatter2D
## of the scene being edited, in tree order (the same as pressing «Scatter» on each).

const MENU := "PropKit: Scatter the open scene"


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _on_scatter_all)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)


func _on_scatter_all() -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		push_warning("PropKit: open a scene first")
		return
	print("PropKit: %d props planted" % PropScatterRun.run_all(scene))
