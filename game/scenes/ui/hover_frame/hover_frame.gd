@tool
class_name HoverFrame
extends Control

## The four corner brackets that surround the unit, building or soul under the pointer, in its side color (soul colors for a
## soul). It reads what is hovered from TargetProbe (the one owner of that ray), projects the body's box with the active
## camera each frame and never shows over a corpse, the sky, the ground, the HUD or while a drag (camera or selection
## rectangle) runs. Local presentation only: no sim reads it. The name box beside the pointer is TargetInfoPanel's.
## Ref: renderer.d:3976-4021 (renderTargetFrame), dagonBackend.d:2048-2058.

@export var probe: TargetProbe
## Optional: while an icon waits for a target (spell, order) buildings are framed too.
@export var armed: ArmedCommand
## The rectangle that the selection drag draws; visible means a drag is running.
@export var selection_box: Control
@export_group("Look")
@export var thickness_px := 2.0
@export var corner_length_px := 12.0
## Smallest frame, so a tiny or far body still gets a readable one.
@export var min_size_px := Vector2(48.0, 48.0)
@export var padding_px := 4.0
@export var soul_own_color := Color(0.0, 182.0 / 255.0, 1.0)
@export var soul_other_color := Color(1.0, 0.0, 0.0)
@export_group("Rules")
## Frame buildings while nothing is armed too (the original frames them only with an icon waiting).
@export var buildings_idle := true

## Read-only views for flows and checks.
var frame_rect := Rect2()
var frame_color := Color.WHITE


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if probe == null:
		warnings.append("Asigná `probe` (el TargetProbe que dice qué hay bajo el puntero).")
	return warnings


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var camera := get_viewport().get_camera_3d()
	if probe == null or camera == null or not _wanted():
		_hide()
		return
	var node := probe.hovered
	var rect := HoverFrameRules.screen_rect(camera, HoverFrameRules.world_corners(node))
	if rect.size == Vector2.ZERO:
		_hide()
		return
	frame_rect = HoverFrameRules.fit(rect, min_size_px, padding_px)
	frame_color = HoverFrameRules.color_of(node, probe.kind, soul_own_color, soul_other_color)
	visible = true
	queue_redraw()


func _draw() -> void:
	var r := frame_rect
	var arm := minf(corner_length_px, minf(r.size.x, r.size.y) * 0.5)
	var half := thickness_px * 0.5
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var dx := arm if corner.x == r.position.x else -arm
		var dy := arm if corner.y == r.position.y else -arm
		var pad_x := half if dx > 0.0 else -half
		var pad_y := half if dy > 0.0 else -half
		draw_line(corner - Vector2(pad_x, 0.0), corner + Vector2(dx, 0.0), frame_color, thickness_px)
		draw_line(corner - Vector2(0.0, pad_y), corner + Vector2(0.0, dy), frame_color, thickness_px)


func _wanted() -> bool:
	var dragging := selection_box != null and selection_box.visible
	return HoverFrameRules.should_show(probe.hovered, probe.kind, armed != null and armed.is_armed(), dragging, buildings_idle)


func _hide() -> void:
	if visible:
		visible = false
