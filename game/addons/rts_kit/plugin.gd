@tool
extends EditorPlugin

## Project > Tools > "RtsKit: Add default input actions" writes the kit's default bindings
## (RtsKeymap) into the project's Input Map, so they can be rebound there. Actions that already exist
## are left as they are.

const MENU := "RtsKit: Add default input actions"


func _enter_tree() -> void:
	add_tool_menu_item(MENU, _on_add_actions)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU)


func _on_add_actions() -> void:
	var added := 0
	for action: StringName in RtsKeymap.bindings(true):
		var key := "input/%s" % action
		if ProjectSettings.has_setting(key):
			continue
		ProjectSettings.set_setting(
			key, {"deadzone": 0.5, "events": RtsKeymap.bindings(true)[action]}
		)
		added += 1
	ProjectSettings.save()
	print("RtsKit: %d input actions added to the project (Project Settings > Input Map)" % added)
