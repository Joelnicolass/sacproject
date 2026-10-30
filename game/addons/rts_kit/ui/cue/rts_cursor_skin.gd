@tool
class_name RtsCursorSkin
extends Node

## The game's mouse cursor: the `free_cursors` picture while nothing is armed and the `target_cursors`
## one while something waits for its target, chosen by what lies under the pointer (RtsTargetProbe),
## and `blocked_cursor` while the armed thing would be refused there (RtsCommandState.aim_status). The
## pictures come from `cues`; without one the system cursor stays. The hardware cursor is drawn by the
## OS in window pixels, so Godot's stretch does not scale it: its side is `cursor_px` canvas pixels
## times window height over canvas height, hot spot at the top center. It does nothing headless.

## The cursor changed: its picture's name and the image applied (null: the system cursor).
signal changed(cursor_name: String, texture: Texture2D)

## Hardware cursor limits, in window pixels.
const MIN_PX := 8
const MAX_PX := 256

@export var cues: RtsCueSet
@export var state: RtsCommandState
@export var probe: RtsTargetProbe
@export var enabled := true
## Side of the cursor in canvas pixels.
@export var cursor_px := 38.4

## Name of the cursor chosen at the last refresh ("" before the first).
var current := ""
## Times the hardware cursor was set (a test reads it: a headless process shows 0).
var apply_count := 0
## Side in window pixels of the cursor last applied.
var applied_px := 0

var _source: Texture2D


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if cues == null:
		warnings.append("Assign `cues` (an RtsCueSet).")
	if probe == null:
		warnings.append("Assign `probe` (an RtsTargetProbe).")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if probe:
		probe.kind_changed.connect(_refresh.unbind(1))
	if state:
		state.armed_changed.connect(_refresh.unbind(2))
		state.aim_changed.connect(_refresh.unbind(2))
	get_viewport().size_changed.connect(_refresh)
	_refresh.call_deferred()


func _exit_tree() -> void:
	if Engine.is_editor_hint() or apply_count == 0:
		return
	Input.set_custom_mouse_cursor(null)


func _refresh() -> void:
	if not enabled or cues == null or not is_inside_tree():
		return
	var armed := state != null and state.is_armed()
	var kind: StringName = probe.kind if probe else RtsTargetProbe.NONE
	var next := cues.cursor_for(kind, armed, armed and state.aim_status != &"")
	var px := physical_px()
	if next == _source and px == applied_px:
		return
	_source = next
	current = next.resource_path.get_file().get_basename() if next else ""
	applied_px = px
	var texture := _sized(next, px)
	changed.emit(current, texture)
	_apply(texture, px)


## The picture at `px` window pixels a side, or null.
func _sized(source: Texture2D, px: int) -> Texture2D:
	var image := source.get_image() if source else null
	if image == null or image.is_empty():
		return null
	var side := clampi(px, MIN_PX, MAX_PX)
	if image.get_width() != side or image.get_height() != side:
		image = image.duplicate()
		image.resize(side, side, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(image)


## Side in window pixels the cursor is drawn at.
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
