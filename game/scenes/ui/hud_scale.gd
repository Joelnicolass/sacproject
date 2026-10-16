@tool
class_name HudScale
extends Resource

## The one size knob of the HUD: the spell book, the selection roster, the armed icon and the cursor
## read it, so they grow and shrink together and stay aligned. sacengine measures the HUD on a
## 480-unit-high screen (hudScaling = height/480, dagonBackend.d:311); the original's own captures
## show it smaller, as if measured on 600 (visual/refs/original/orig_4_manantial.webp). So
## pixels = units · scale · height / `base_height`, with scale 0.8 = the original (default) and
## 1.0 = sacengine, free between `min_scale` and `max_scale`.
##
## The player's choice lives in `user://settings.cfg` (`[hud] scale`, through UserSettings). `--hud-scale=` on the
## command line wins for one run and is not saved. Options → Gráficos (RFC-031 031c) changes it with `set_scale`;
## the inspector of `data/ui/hud_scale.tres` (`default_scale`) sets the value when the player chose nothing.
## The value is runtime state of this shared instance; the exported fields are never written.

const SECTION := "hud"
const KEY := "scale"
const ARG := "--hud-scale="
## sacengine's HUD height (hudScaling = height/480, dagonBackend.d:311).
const SACENGINE_HEIGHT := 480.0
## The one instance every HUD node must share (a copy would not follow the player's choice).
const SHARED_PATH := "res://data/ui/hud_scale.tres"
## Hardware cursor limit, also used for the icons drawn at the pointer.
const MIN_PX := 8
const MAX_PX := 256

## Screen height the HUD units are measured on (sacengine: 480).
@export var base_height := SACENGINE_HEIGHT
## Size when the player chose nothing: 0.8 = the original's captures, 1.0 = sacengine.
@export_range(0.6, 1.2, 0.05) var default_scale := 0.8
@export var min_scale := 0.6
## Above ~1.15 the roster would reach the spell book at any height; SelectionRoster.avoid shrinks it.
@export var max_scale := 1.2

var _scale := -1.0


## Current scale: command line, then the settings file, then `default_scale`; clamped.
func get_scale() -> float:
	if Engine.is_editor_hint():
		return clampf(default_scale, min_scale, max_scale)
	if _scale < 0.0:
		_scale = clampf(_initial_scale(), min_scale, max_scale)
	return _scale


## Sets and saves the player's scale; emits `changed` when it differs.
func set_scale(value: float, save := true) -> void:
	var next := clampf(value, min_scale, max_scale)
	if is_equal_approx(next, get_scale()):
		return
	_scale = next
	if save and not Engine.is_editor_hint():
		_save(next)
	emit_changed()


## Screen pixels per HUD unit on a viewport `viewport_height` high.
func factor(viewport_height: float) -> float:
	return get_scale() * viewport_height / base_height


## Side in whole pixels of something `units` HUD units wide, within MIN_PX…MAX_PX (cursor and the
## icons drawn at the pointer use this one, so they stay aligned).
func px(units: float, viewport_height: float) -> int:
	return clampi(roundi(units * factor(viewport_height)), MIN_PX, MAX_PX)


## Warning text for a node whose `hud_scale` is not the shared instance ("" when it is).
static func socket_warning(scale: HudScale) -> String:
	if scale == null:
		return "Asigná `hud_scale` (%s)." % SHARED_PATH
	if scale.resource_path != SHARED_PATH:
		return "`hud_scale` no es %s: este nodo no seguirá el tamaño elegido por el jugador." % SHARED_PATH
	return ""


func _save(value: float) -> void:
	UserSettings.write_values(SECTION, {KEY: value})


func _initial_scale() -> float:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(ARG):
			var text := arg.substr(ARG.length())
			if text.is_valid_float() and is_finite(text.to_float()):
				return text.to_float()
			push_warning("HudScale: %s no es un número; se usa el valor por defecto." % arg)
			return default_scale
	var stored: Variant = UserSettings.read_value(SECTION, KEY, default_scale)
	if typeof(stored) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(stored)):
		return float(stored)
	push_warning("HudScale: [%s] %s en %s no es un número; se usa el valor por defecto." % [SECTION, KEY, UserSettings.PATH])
	return default_scale
