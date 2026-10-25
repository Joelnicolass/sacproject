@tool
class_name CursorSkin
extends Node

## The mouse cursor of the original game (RFC-025c): `C*` of curs.FLDR while nothing is armed and
## `T*` while an icon waits for its target, chosen by what lies under the pointer (TargetProbe) like
## sacengine `cursor()` (state.d:30830). The pictures are the ones of `cues` (data/ui/command_cues.tres); without
## one the system cursor stays. The hardware cursor is drawn by the OS in window pixels, so Godot's stretch does not scale it: its
## side is `cursor_px` canvas pixels times window height over canvas height, hot spot at the top center. It does nothing in a
## headless process or in the dedicated server (no player, no window), and nothing over the HUD beyond picking the plain arrow.
## Ref: renderer.d:4113 renderCursor (32 units, ×1.2).

## The cursor changed: its name (`Tnme`) and image (null without cache).
signal changed(cursor_name: String, texture: Texture2D)

@export var cues: CueSet
@export var command_log: CommandLog
@export var probe: TargetProbe
@export var enabled := true
## Side of the cursor in canvas pixels of the 1280×720 base.
@export var cursor_px := 38.4
## The interface size: when the player changes it the cursor is measured again.
@export var ui_scale: UiScalePrefs

## Hardware cursor limits, in window pixels.
const MIN_PX := 8
const MAX_PX := 256

## Name of the cursor chosen at the last refresh (`""` before the first).
var current := ""
## Times the hardware cursor was set (a flow reads it: the dedicated server must show 0).
var apply_count := 0
## Side in window pixels of the cursor last applied (a capture reads it).
var applied_px := 0

var _announced := false
var _source: Texture2D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if cues == null:
		warnings.append("Asigná `cues` (data/ui/command_cues.tres).")
	if command_log == null:
		warnings.append("Asigná `command_log` (el nodo Battle).")
	if probe == null:
		warnings.append("Asigná `probe` (TargetProbe).")
	elif cues.hud_cursor == null:
		warnings.append("Asigná `hud_cursor` en `cues`. Sin eso queda el cursor del sistema.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if probe:
		probe.kind_changed.connect(_refresh.unbind(1))
	if command_log:
		command_log.armed_changed.connect(_refresh.unbind(2))
	get_viewport().size_changed.connect(_refresh)
	if ui_scale:
		ui_scale.changed.connect(_refresh.call_deferred)
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
	var px := physical_px()
	if next == _source and px == applied_px:
		return
	_source = next
	current = next.resource_path.get_file().get_basename() if next else ""
	applied_px = px
	var texture := _sized(next, px)
	changed.emit(current, texture)
	_apply(texture, px)


## The picture at `px` window pixels a side (the hardware cursor takes at most 256), or null.
func _sized(source: Texture2D, px: int) -> Texture2D:
	var image := source.get_image() if source else null
	if image == null or image.is_empty():
		return null
	var side := clampi(px, MIN_PX, MAX_PX)
	if image.get_width() != side or image.get_height() != side:
		image = image.duplicate()
		image.resize(side, side, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


## Side in window pixels the cursor is drawn at: `cursor_px` canvas pixels, times how many window pixels one canvas pixel is.
func physical_px() -> int:
	var canvas_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	return clampi(roundi(cursor_px * float(get_window().size.y) / canvas_height), MIN_PX, MAX_PX)


func _apply(texture: Texture2D, px: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if texture == null:
		Input.set_custom_mouse_cursor(null)
		return
	var side := clampi(px, MIN_PX, MAX_PX)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(side * 0.5, 0.0))
	apply_count += 1
