@tool
class_name HoverFrame
extends Control

## The frame around the unit, building or soul under the pointer, in its side color (soul colors for a soul):
## four wedges (one per side, peak alpha near a corner, fading to zero along the side and across its width) that
## stick out of the rect by 5% and scale with it. Plain alpha blending, no animation. It reads what is hovered from TargetProbe
## (the one owner of that ray), projects the body's box with the active camera each frame and never shows over a corpse, the sky,
## the ground, the HUD or while a drag (camera or selection rectangle) runs. Local presentation only: no sim reads it. The name
## box beside the pointer is TargetInfoPanel's.

@export var probe: TargetProbe
## Optional: while an icon waits for a target (spell, order) buildings are framed too.
@export var armed: ArmedCommand
## The rectangle that the selection drag draws; visible means a drag is running.
@export var selection_box: Control
@export_group("Look")
## Smallest frame, so a tiny or far body still gets a readable one.
@export var min_size_px := Vector2(48.0, 48.0)
## Growth of the projected box before the frame.
@export var padding_px := 0.0
@export var soul_own_color := Color(0.0, 182.0 / 255.0, 1.0)
@export var soul_other_color := Color(1.0, 0.0, 0.0)
@export_group("Rules")
## Frame buildings while nothing is armed too (off: only with an icon waiting).
@export var buildings_idle := true

## Read-only views for flows and checks.
var frame_rect := Rect2()
var frame_color := Color.WHITE


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if probe == null:
		warnings.append("Assign `probe` (the TargetProbe that says what is under the pointer).")
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
	var mesh := HoverFrameRules.frame_mesh()
	var points: PackedVector2Array = mesh["points"]
	var alphas: PackedFloat32Array = mesh["alphas"]
	for tri in points.size() / 3:
		var corners := PackedVector2Array()
		var colors := PackedColorArray()
		for k in 3:
			var i := tri * 3 + k
			corners.append(frame_rect.position + points[i] * frame_rect.size)
			colors.append(Color(frame_color, frame_color.a * alphas[i]))
		draw_polygon(corners, colors)


func _wanted() -> bool:
	var dragging := selection_box != null and selection_box.visible
	return HoverFrameRules.should_show(
		probe.hovered, probe.kind, armed != null and armed.is_armed(), dragging, buildings_idle
	)


func _hide() -> void:
	if visible:
		visible = false
