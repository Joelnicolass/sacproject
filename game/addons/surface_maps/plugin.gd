@tool
extends EditorPlugin

## Wires the surface maps into the editor: the settings that say where maps go (`surface_maps/mirror_from`,
## `surface_maps/mirror_to`), the «Relief from albedo» section in the inspector of a material or a ground role, and
## Project > Tools > «Generate relief…» for many at once. Owns the one recipe both share this session (never saved: the
## PNG is the source). Dev only: the export excludes `addons/surface_maps/*`, and nothing in the game refers to it.
## Not: the pixels (ReliefBaker), the files (MapWriter), the UI (surface_panel, batch_dialog).

const Inspector := preload("res://addons/surface_maps/surface_inspector.gd")
const BatchScene := preload("res://addons/surface_maps/batch_dialog.tscn")
const BatchDialog := preload("res://addons/surface_maps/batch_dialog.gd")
const BATCH_ITEM := "Generate relief…"
const SETTINGS := {
	MapWriter.SETTING_FROM: MapWriter.DEFAULT_FROM,
	MapWriter.SETTING_TO: MapWriter.DEFAULT_TO,
}

var _recipe := ReliefRecipe.new()
var _inspector: EditorInspectorPlugin
var _batch: BatchDialog


func _enter_tree() -> void:
	for setting: String in SETTINGS:
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, SETTINGS[setting])
		ProjectSettings.set_initial_value(setting, SETTINGS[setting])
		ProjectSettings.add_property_info({"name": setting, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR})
	_inspector = Inspector.new(get_undo_redo(), _recipe)
	add_inspector_plugin(_inspector)
	_batch = BatchScene.instantiate() as BatchDialog
	_batch.recipe = _recipe
	EditorInterface.get_base_control().add_child(_batch)
	add_tool_menu_item(BATCH_ITEM, _open_batch)


func _exit_tree() -> void:
	remove_tool_menu_item(BATCH_ITEM)
	remove_inspector_plugin(_inspector)
	_batch.queue_free()


func _open_batch() -> void:
	_batch.popup_centered()
