@tool
class_name CursorSkin
extends Node

## The mouse cursor of the original game (RFC-025c): `C*` of curs.FLDR while nothing is armed and
## `T*` while an icon waits for its target, chosen by what lies under the pointer (TargetProbe) like
## sacengine `cursor()` (state.d:30830). The image comes from the local cache (HudIcons.cursor); without
## it the system cursor stays. Size = 32 HUD units (renderCursor, renderer.d:4113; see HudScale), hot spot at the
## top center. It does nothing in a headless process or in the dedicated server (no player, no window),
## and nothing over the HUD beyond picking the plain arrow.

## The cursor changed: its name (`Tnme`) and image (null without cache).
signal changed(cursor_name: String, texture: Texture2D)

@export var cues: CueSet
@export var command_log: CommandLog
@export var probe: TargetProbe
@export var enabled := true
## Shared HUD size (the spell book, the roster and the armed icon read the same one).
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")
## Side of the cursor in HUD units (renderCursor: 32).
@export var cursor_units := 32.0

## Name of the cursor chosen at the last refresh (`""` before the first).
var current := ""
## Times the hardware cursor was set (a flow reads it: the dedicated server must show 0).
var apply_count := 0

var _applied_px := 0
var _announced := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if cues == null:
		warnings.append("Asigná `cues` (data/ui/command_cues.tres).")
	if command_log == null:
		warnings.append("Asigná `command_log` (el nodo Battle).")
	if probe == null:
		warnings.append("Asigná `probe` (TargetProbe).")
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	if HudIcons.cursor("Cnor") == null:
		warnings.append("Falta cache/look/cursors: corré tools/export_icons.py. Sin eso queda el cursor del sistema.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if probe:
		probe.kind_changed.connect(_refresh.unbind(1))
	if command_log:
		command_log.armed_changed.connect(_refresh.unbind(2))
	get_viewport().size_changed.connect(_refresh)
	if hud_scale:
		hud_scale.changed.connect(_refresh)
	_refresh.call_deferred()


func _exit_tree() -> void:
	if Engine.is_editor_hint() or apply_count == 0:
		return
	Input.set_custom_mouse_cursor(null)


func _refresh() -> void:
	if not enabled or cues == null:
		return
	if MpKit.local_slot() <= 0:
		if not _announced:
			_announced = true
			print("CursorSkin: sin jugador local, no se toca el cursor del sistema")
		return
	var armed := command_log != null and not command_log.armed.is_empty()
	var kind: StringName = probe.kind if probe else &"none"
	var next := cues.cursor_for(kind, armed)
	var height := get_viewport().get_visible_rect().size.y
	var px := hud_scale.px(cursor_units, height) if hud_scale else roundi(cursor_units * height / HudScale.SACENGINE_HEIGHT)
	if next == current and px == _applied_px:
		return
	current = next
	_applied_px = px
	var texture := HudIcons.cursor_sized(next, clampi(px, HudScale.MIN_PX, HudScale.MAX_PX))
	changed.emit(next, texture)
	_apply(texture, px)


func _apply(texture: Texture2D, px: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if texture == null:
		Input.set_custom_mouse_cursor(null)
		return
	var side := clampi(px, HudScale.MIN_PX, HudScale.MAX_PX)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(side * 0.5, 0.0))
	apply_count += 1
