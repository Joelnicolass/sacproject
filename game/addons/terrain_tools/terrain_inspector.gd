@tool
extends EditorInspectorPlugin

## Puts the ground's buttons (TerrainPanel) at the top of the inspector of every Terrain: «Open in Blender», «Traer de
## Blender», «New flat ground», «Flatten bases» and «Validate map». Not: what they do (TerrainActions).

const PanelScene := preload("res://addons/terrain_tools/terrain_panel.tscn")
const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")

var _actions: TerrainActions


func _init(actions: TerrainActions) -> void:
	_actions = actions


func _can_handle(object: Object) -> bool:
	return object is Terrain


func _parse_begin(object: Object) -> void:
	var panel := PanelScene.instantiate()
	panel.terrain = object as Terrain
	panel.actions = _actions
	add_custom_control(panel)
