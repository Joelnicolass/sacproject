@tool
class_name UiScalePrefs
extends Resource

## The player's choice of interface size, saved in `user://settings.cfg` `[ui] scale`. It only holds the number: UiScaleApplier
## puts it on the window (Window.content_scale_factor) and Options → Gráficos moves it. It draws and scales nothing itself.
## Without a choice the value is Project Settings › Display › Window › Stretch › Scale. `--ui-scale=<n>` wins for one run and is not
## saved. Every node shares the instance at `SHARED_PATH` (a copy would not follow the player's choice).

const SHARED_PATH := "res://data/ui/ui_scale.tres"
const SECTION := "ui"
const KEY := "scale"
const ARG := "--ui-scale="
const PROJECT_SETTING := "display/window/stretch/scale"

## The smallest and the biggest interface the player can pick. At 1.4 the roster still clears the book (canvas 514 px high).
@export var min_scale := 0.75
@export var max_scale := 1.4

var _scale := -1.0


## The size in use: command line, then the settings file, then the project's stretch scale; clamped.
func get_scale() -> float:
	if _scale < 0.0 or Engine.is_editor_hint():
		_scale = clampf(_initial(), min_scale, max_scale)
	return _scale


## Sets and saves the player's size; emits `changed` when it differs.
func set_scale(value: float, save := true) -> void:
	var next := clampf(value, min_scale, max_scale)
	if is_equal_approx(next, get_scale()):
		return
	_scale = next
	if save and not Engine.is_editor_hint():
		UserSettings.write_values(SECTION, {KEY: next})
	emit_changed()


func _initial() -> float:
	var fallback := float(ProjectSettings.get_setting(PROJECT_SETTING, 1.0))
	if Engine.is_editor_hint():
		return fallback
	var text := _cli_text()
	if text.is_valid_float() and is_finite(text.to_float()):
		return text.to_float()
	var stored: Variant = UserSettings.read_value(SECTION, KEY, fallback)
	return (
		float(stored)
		if typeof(stored) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(stored))
		else fallback
	)


func _cli_text() -> String:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(ARG):
			return arg.substr(ARG.length())
	return ""
