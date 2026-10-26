@tool
class_name FeelPrefs
extends Resource

## RFC-053 053e/053f (F374, F375): the player's combat-feel choices, a local preference (never a match rule, never sent).
## - `shake_scale` (0-1): how much the camera shakes (CameraShake); 0 turns it off.
## - `damage_numbers`: the floating numbers over the bodies that lose health (DamageNumbers).
## - `hover_info`: the info box beside the pointer (TargetInfoPanel).
## - `blood`: «Sangre», the blood of the hits, its marks on the ground and the hit flash (BloodFx, SprayMarks, HitFlash).
## - It lives in `user://settings.cfg` `[sensacion]` through UserSettings (sandboxed under AgentKit, like the others).
## Like GraphicsPrefs, every node must share the instance at `SHARED_PATH`; the values are runtime state of that instance and
## the exported fields (the defaults) are never written. Changes emit `changed`.

const SHARED_PATH := "res://data/ui/feel_prefs.tres"
const SECTION := "sensacion"

## When the player chose nothing.
@export_range(0.0, 1.0, 0.05) var default_shake_scale := 0.5
@export var default_damage_numbers := true
@export var default_hover_info := true
@export var default_blood := true

var _loaded := false
var _shake_scale := 0.5
var _damage_numbers := true
var _hover_info := true
var _blood := true


func shake_scale() -> float:
	_ensure_loaded()
	return _shake_scale


func damage_numbers() -> bool:
	_ensure_loaded()
	return _damage_numbers


func hover_info() -> bool:
	_ensure_loaded()
	return _hover_info


func blood() -> bool:
	_ensure_loaded()
	return _blood


## `save` false: this run only (a check that must not write the file).
func set_shake_scale(value: float, save := true) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, shake_scale()):
		return
	_shake_scale = next
	_commit(save)


func set_damage_numbers(on: bool, save := true) -> void:
	if on == damage_numbers():
		return
	_damage_numbers = on
	_commit(save)


func set_hover_info(on: bool, save := true) -> void:
	if on == hover_info():
		return
	_hover_info = on
	_commit(save)


func set_blood(on: bool, save := true) -> void:
	if on == blood():
		return
	_blood = on
	_commit(save)


## Warning text for a node whose `prefs` is not the shared instance ("" when it is).
static func socket_warning(prefs: FeelPrefs) -> String:
	if prefs == null:
		return "Asigná `prefs` (%s)." % SHARED_PATH
	if prefs.resource_path != SHARED_PATH:
		return "`prefs` no es %s: este nodo no seguirá la elección del jugador." % SHARED_PATH
	return ""


func _commit(save: bool) -> void:
	if save and not Engine.is_editor_hint():
		UserSettings.write_values(SECTION, {
			"shake_scale": _shake_scale,
			"damage_numbers": _damage_numbers,
			"hover_info": _hover_info,
			"blood": _blood,
		})
	emit_changed()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_shake_scale = clampf(default_shake_scale, 0.0, 1.0)
	_damage_numbers = default_damage_numbers
	_hover_info = default_hover_info
	_blood = default_blood
	if Engine.is_editor_hint():
		return
	var shake: Variant = UserSettings.read_value(SECTION, "shake_scale", _shake_scale)
	if typeof(shake) in [TYPE_INT, TYPE_FLOAT]:
		_shake_scale = clampf(float(shake), 0.0, 1.0)
	_damage_numbers = _read_bool("damage_numbers", _damage_numbers)
	_hover_info = _read_bool("hover_info", _hover_info)
	_blood = _read_bool("blood", _blood)


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = UserSettings.read_value(SECTION, key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback
