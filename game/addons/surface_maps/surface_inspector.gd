@tool
extends EditorInspectorPlugin

## Puts the «Relief from albedo» section (surface_panel.tscn) at the top of the inspector of every BaseMaterial3D and of
## any Resource with an `albedo` and a `normal` or `orm` texture (a ground role, without naming it). Hands each section
## the session's recipe and the editor's undo. Not: the section itself (surface_panel), the pixels, the files.

const PanelScene := preload("res://addons/surface_maps/surface_panel.tscn")
const SurfacePanel := preload("res://addons/surface_maps/surface_panel.gd")

var _undo: EditorUndoRedoManager
var _recipe: ReliefRecipe


func _init(undo: EditorUndoRedoManager, recipe: ReliefRecipe) -> void:
	_undo = undo
	_recipe = recipe


func _can_handle(object: Object) -> bool:
	if object is BaseMaterial3D:
		return true
	return object is Resource and "albedo" in object and ("normal" in object or "orm" in object)


func _parse_begin(object: Object) -> void:
	var panel := PanelScene.instantiate() as SurfacePanel
	panel.setup(object as Resource, _recipe, _undo)
	add_custom_control(panel)
