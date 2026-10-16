extends Node

## F142 diagnostic, read-only. Tolerates scene == null.
##   hit(name)  lists the visible Controls that take the mouse (filter != IGNORE) and contain the global centre of the
##              unique node `name` of the running scene, with their CanvasLayer layer, and the hovered control.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func hit(target_name: String) -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return "no scene"
	var target := tree.current_scene.find_child(target_name, true, false) as Control
	if target == null:
		return "no %s" % target_name
	var point := target.get_global_rect().get_center()
	var hits: Array[String] = []
	for node in tree.root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not control.get_global_rect().has_point(point):
			continue
		var layer := control.get_canvas_layer_node()
		hits.append("%s[%s L%s]" % [control.name, control.get_class(), layer.layer if layer else "-"])
	var hovered := get_viewport().gui_get_hovered_control()
	var line := "pt142hit %s at %s hovered=%s hits=%s" % [target_name, point, hovered.name if hovered else "-", hits]
	print(line)
	return line
