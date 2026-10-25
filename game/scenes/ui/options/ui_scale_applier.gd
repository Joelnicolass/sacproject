@tool
class_name UiScaleApplier
extends Node

## Puts the player's interface size on the window, at start and live on every change; the one writer of Window.content_scale_factor.
## It does nothing else: the stretch (canvas_items + expand, 1280×720 base) scales every widget, so no widget reads the size.
## Inert in the editor, in a headless process and in the dedicated server (no window to scale). Under AgentKit the preference is
## the in-memory sandbox (UserSettings), so a run starts at the project's scale unless `--ui-scale=` says otherwise.
## A scene that can open the options (the boot, the match) holds one; the window keeps the factor when the scene is swapped.

## The shared preference (data/ui/ui_scale.tres).
@export var prefs: UiScalePrefs


func _ready() -> void:
	if _inert() or prefs == null:
		return
	prefs.changed.connect(apply)
	apply()


## Writes the preference on the window; cheap when nothing changed.
func apply() -> void:
	if _inert() or prefs == null or not is_inside_tree():
		return
	var window := get_window()
	if not is_equal_approx(window.content_scale_factor, prefs.get_scale()):
		window.content_scale_factor = prefs.get_scale()


func _inert() -> bool:
	return Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or MpBoot.is_dedicated_process()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if prefs != null else PackedStringArray(["Asigná `prefs` (%s)." % UiScalePrefs.SHARED_PATH])
