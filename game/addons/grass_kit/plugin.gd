@tool
extends EditorPlugin

## GrassKit in the editor. Select a GrassField3D and the 3D view gets its tools: the «GrassKit» menu
## and four brushes on top of the view, their settings under it (editor/grass_paint_tool.gd). In
## the 3D view: a GrassClear3D's circles and a field's ground area, each with handles to drag. A
## field added to a scene sets itself up (a ground fitted to the colliders, the meadow look, medium
## quality, a wind) and, when the scene has colliders and has been saved, bakes its ground.
## Project > Tools: "GrassKit: Bake the open scene". The painted maps are saved inside the ground
## when the scene is saved.
##
## Enabling the plugin, and every time the editor starts with it, adds GrassKit's global shader
## uniforms to Project Settings > Shader Globals (the wind, and where the grass ends), only the
## ones missing and no other, so the game's own shaders that include grass_wind.gdshaderinc or
## grass_ground.gdshaderinc compile from the start. Disabling it leaves them: a game's shader may
## still read them (remove them by hand there if none does).

const BAKE_MENU := "GrassKit: Bake the open scene"

var _gizmos: EditorNode3DGizmoPlugin
var _tool: Node


func _enable_plugin() -> void:
	if GrassGlobals.add_to_project():
		ProjectSettings.save()


func _enter_tree() -> void:
	# A newer GrassKit may bring a global the project lacks.
	if GrassGlobals.add_to_project():
		ProjectSettings.save()
	_tool = preload("editor/grass_paint_tool.gd").new()
	add_child(_tool)
	var bars: Array[Control] = _tool.call(&"bars")
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, bars[0])
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_BOTTOM, bars[1])
	_gizmos = preload("editor/grass_gizmos.gd").new()
	_gizmos.set(&"tool", _tool)
	add_node_3d_gizmo_plugin(_gizmos)
	add_tool_menu_item(BAKE_MENU, _bake_open_scene)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	remove_tool_menu_item(BAKE_MENU)
	remove_node_3d_gizmo_plugin(_gizmos)
	var bars: Array[Control] = _tool.call(&"bars")
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, bars[0])
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_BOTTOM, bars[1])
	for bar in bars:
		bar.queue_free()
	_tool.queue_free()


func _handles(object: Object) -> bool:
	return object is GrassField3D


func _edit(object: Object) -> void:
	_tool.call(&"edit", object as GrassField3D)


func _make_visible(visible: bool) -> void:
	_tool.call(&"set_visible", visible)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return _tool.call(&"input", camera, event)


func _save_external_data() -> void:
	_tool.call(&"save_painted")


## Every GrassField3D of the open scene bakes its ground (each one step of the history).
func _bake_open_scene() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_warning("GrassKit: open a scene first")
		return
	for node in root.find_children("*", "GrassField3D", true, false):
		(node as GrassField3D)._bake_in_editor()


## A field just made in the editor (it has no owner yet; one loaded with a scene has): it sets
## itself up once it is in place.
func _on_node_added(node: Node) -> void:
	if node is GrassField3D and node.owner == null and Engine.is_editor_hint():
		_set_up_new.call_deferred(node)


func _set_up_new(field: GrassField3D) -> void:
	if not is_instance_valid(field) or not field.is_inside_tree():
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null or field == root or not root.is_ancestor_of(field):
		return
	if field.ground != null or field.look != null or field.quality != null or field.wind != null:
		return
	var made := field.set_up()
	print("GrassKit: %s set up (%s); select it to paint" % [field.name, ", ".join(made)])
	if field.colliders_area(false).has_area() and not root.scene_file_path.is_empty():
		field._bake_in_editor()
