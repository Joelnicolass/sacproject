@tool
extends EditorPlugin

## The terrain tools of the editor, wired together: the importer of a map's heights.png and void.png (and a reimport of
## heights.png when the void.png beside it changes, since an importer reads one source file), the ground's buttons in a
## Terrain's inspector, and the ground brush (its bar in the 3D menu, the mouse in the 3D viewport while a Terrain is
## selected, the pictures written on save). Dev only: the export excludes `addons/terrain_tools/*`.
## Not: any of those tools (each is its own script), what a map's ground is (Terrain).

const Importer := preload("res://addons/terrain_tools/terrain_heights_importer.gd")
const MapImages := preload("res://addons/terrain_tools/map_images.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")
const Inspector := preload("res://addons/terrain_tools/terrain_inspector.gd")
const ToolbarScene := preload("res://addons/terrain_tools/brush/brush_toolbar.tscn")
const BrushPainter := preload("res://addons/terrain_tools/brush/brush_painter.gd")
const EditorDialogs := preload("res://addons/terrain_tools/editor_dialogs.gd")
const NewMapAction := preload("res://addons/terrain_tools/new_map/new_map_action.gd")
const NEW_MAP_ITEM := "Mapa nuevo…"

var _importer: EditorImportPlugin
var _history: TerrainHistory
var _inspector: EditorInspectorPlugin
var _toolbar: Control
var _painter: BrushPainter
var _new_map: NewMapAction


func _enter_tree() -> void:
	_importer = Importer.new()
	add_import_plugin(_importer)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_on_resources_reimported)
	_history = TerrainHistory.new(get_undo_redo())
	_inspector = Inspector.new(TerrainActions.new(_history))
	add_inspector_plugin(_inspector)
	_toolbar = ToolbarScene.instantiate()
	_toolbar.visible = false
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
	_painter = BrushPainter.new(_history, _toolbar)
	_toolbar.rebuild_pressed.connect(_painter.rebuild)
	_add_new_map_item()


func _exit_tree() -> void:
	_remove_new_map_item()
	_painter.release()
	_history.budget.finish()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _toolbar)
	_toolbar.queue_free()
	remove_inspector_plugin(_inspector)
	EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_on_resources_reimported)
	remove_import_plugin(_importer)
	_importer = null
	_inspector = null
	_painter = null
	_history = null


func _handles(object: Object) -> bool:
	return object is Terrain


func _edit(object: Object) -> void:
	_painter.edit(object as Terrain)


func _make_visible(visible: bool) -> void:
	_toolbar.visible = visible
	if not visible:
		_toolbar.reset()
		_painter.edit(null)


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return AFTER_GUI_INPUT_STOP if _painter.input(camera, event) else AFTER_GUI_INPUT_PASS


## Ctrl+S: the heights the brushes or «Aplanar bases» changed go to their heights.png and void.png.
func _save_external_data() -> void:
	var errors := _history.save()
	if not errors.is_empty():
		EditorDialogs.say("Terreno: no se pudo guardar", errors)


## Closing the editor with heights not yet written asks first.
func _get_unsaved_status(for_scene: String) -> String:
	return "Hay alturas del terreno sin guardar en heights.png." if for_scene.is_empty() and _history.has_unsaved() else ""


## A void.png came in or changed: the heights.png beside it imports again, unless it already did in the same batch.
func _on_resources_reimported(resources: PackedStringArray) -> void:
	var stale := PackedStringArray()
	for path in resources:
		if path.get_file() != MapImages.VOID_FILE:
			continue
		var heights := path.get_base_dir().path_join(MapImages.HEIGHTS_FILE)
		if FileAccess.file_exists(heights) and not resources.has(heights) and not stale.has(heights):
			stale.append(heights)
	if not stale.is_empty():
		EditorInterface.get_resource_filesystem().reimport_files.call_deferred(stale)


## Project → Tools → «Mapa nuevo…»: a map folder made from scenes/map/maps/_template/ (NewMapAction).
func _add_new_map_item() -> void:
	_new_map = NewMapAction.new(TerrainActions.new(_history))
	add_tool_menu_item(NEW_MAP_ITEM, _new_map.open)


func _remove_new_map_item() -> void:
	remove_tool_menu_item(NEW_MAP_ITEM)
	_new_map = null
