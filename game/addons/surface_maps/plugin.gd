@tool
extends EditorPlugin

## Wires the surface maps into the editor. For now only the settings that say where maps go (`surface_maps/mirror_from`,
## `surface_maps/mirror_to`); the inspector section and the batch dialog come next. Dev only: the export excludes
## `addons/surface_maps/*`, and nothing in the game refers to it. Not: the pixels (ReliefBaker), the files (MapWriter).

const SETTINGS := {
	MapWriter.SETTING_FROM: MapWriter.DEFAULT_FROM,
	MapWriter.SETTING_TO: MapWriter.DEFAULT_TO,
}


func _enter_tree() -> void:
	for setting: String in SETTINGS:
		if not ProjectSettings.has_setting(setting):
			ProjectSettings.set_setting(setting, SETTINGS[setting])
		ProjectSettings.set_initial_value(setting, SETTINGS[setting])
		ProjectSettings.add_property_info({"name": setting, "type": TYPE_STRING, "hint": PROPERTY_HINT_DIR})
