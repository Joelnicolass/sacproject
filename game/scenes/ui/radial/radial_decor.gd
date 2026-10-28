@tool
class_name RadialDecor
extends Control

## What a radial menu draws behind its icons: the rings, the sector the pointer is in, a line toward the pointer
## and, in the dead zone, the hovered name (and the shape of a formation in dots). It is the only owner of the pointer state it
## draws (`set_hover`); the menu only feeds it. The name is drawn with `draw_string`, not a Label: the HUD text audit
## counts Controls with text. Canvas pixels of the 1280×720 base.

@export_group("Look")
@export var backdrop_color := Color(0.03, 0.03, 0.06, 0.5)
@export var ring_tint := Color(0.16, 0.12, 0.05, 0.38)
@export var center_color := Color(0.02, 0.02, 0.04, 0.8)
@export var line_color := Color(0.85, 0.7, 0.3, 0.7)
@export var wedge_color := Color(1.0, 0.82, 0.3, 0.3)
@export var pointer_color := Color(1.0, 0.88, 0.45, 0.85)
@export var text_color := Color(1.0, 0.95, 0.8, 1.0)
@export var text_outline := Color(0, 0, 0, 1)
@export_range(6, 20) var font_size := 11
@export var dot_color := Color(1.0, 0.85, 0.4, 1.0)
@export var dot_radius := 2.3
## Side of the box the formation dots are fitted in.
@export var preview_px := 31.0
@export_group("Animation")
## Seconds the sector takes to fade in when the pointer changes of entry.
@export var fade_s := 0.12
@export_group("Sockets")
@export var center_rect: TextureRect

var layout: RadialLayout

var _spot := Vector2i(-1, -1)
var _offset := Vector2.ZERO
var _entry: RadialEntry
var _alpha := 0.0
var _fade: Tween


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray() if center_rect != null else PackedStringArray(["Assign center_rect."])
	)


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


## Called by the menu when its size changes: the dead zone picture goes in the middle.
func fit(value: RadialLayout) -> void:
	layout = value
	var middle := Vector2.ONE * layout.outer_radius_px
	center_rect.size = Vector2.ONE * layout.dead_zone_px * 1.5
	center_rect.position = middle - center_rect.size * 0.5
	queue_redraw()


## Redraws every frame (the sector fades) only while the menu is open.
func set_active(active: bool) -> void:
	set_process(active)
	queue_redraw()


## `spot`: where the pointer is (`RadialLayout.locate`); `offset`: from the menu center; `entry`: what is under it.
## `restart`: the entry changed, so the sector fades in again.
func set_hover(spot: Vector2i, offset: Vector2, entry: RadialEntry, restart: bool) -> void:
	_spot = spot
	_offset = offset
	_entry = entry if spot.x >= 1 else null
	if restart:
		if _fade:
			_fade.kill()
		_alpha = 0.0
		if _entry != null and not Engine.is_editor_hint():
			_fade = create_tween()
			_fade.tween_property(self, "_alpha", 1.0, fade_s)
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return
	var middle := Vector2.ONE * layout.outer_radius_px
	draw_circle(middle, layout.outer_radius_px, backdrop_color)
	draw_circle(middle, layout.inner_radius_px, ring_tint)
	draw_circle(middle, layout.dead_zone_px, center_color)
	draw_arc(middle, layout.dead_zone_px, 0.0, TAU, 48, line_color, 1.2, true)
	draw_arc(middle, layout.inner_radius_px, 0.0, TAU, 64, line_color, 1.2, true)
	draw_arc(middle, layout.outer_radius_px, 0.0, TAU, 64, line_color, 1.8, true)
	_draw_wedge(middle)
	_draw_pointer(middle)
	_draw_center(middle)


## The sector of the hovered ring entry, filled.
func _draw_wedge(middle: Vector2) -> void:
	if _spot.x < 1 or _spot.y < 0 or _alpha <= 0.0:
		return
	var count := layout.inner.size() if _spot.x == 1 else layout.outer.size()
	var r0 := layout.dead_zone_px if _spot.x == 1 else layout.inner_radius_px
	var r1 := layout.inner_radius_px if _spot.x == 1 else layout.outer_radius_px
	var step := TAU / count
	var from := step * (_spot.y - 0.5) - PI * 0.5
	var points := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var a := from + step * i / steps
		points.append(middle + Vector2(cos(a), sin(a)) * r1)
	for i in steps + 1:
		var a := from + step * (steps - i) / steps
		points.append(middle + Vector2(cos(a), sin(a)) * r0)
	var color := wedge_color
	color.a *= _alpha
	draw_colored_polygon(points, color)


## A line from the center toward the pointer, up to the outer ring.
func _draw_pointer(middle: Vector2) -> void:
	if _spot.x < 1:
		return
	var direction := _offset.normalized()
	var tip := middle + direction * minf(_offset.length(), layout.outer_radius_px)
	var base := middle + direction * layout.dead_zone_px
	draw_line(base, tip, pointer_color, 2.4, true)
	draw_circle(tip, 3.0, pointer_color)


## The hovered name (and the shape of a formation) in the dead zone; the context picture when nothing is hovered.
func _draw_center(middle: Vector2) -> void:
	center_rect.visible = true
	var dead := layout.dead_zone_px
	if _entry == null:
		center_rect.size = Vector2.ONE * dead * 1.5
		center_rect.position = middle - center_rect.size * 0.5
		return
	var up := middle + Vector2(0.0, -dead * 0.32)
	if _entry.formation != null and not Engine.is_editor_hint():
		center_rect.visible = false
		RadialDots.draw(self, _entry.formation, up, preview_px, dot_radius, dot_color, text_outline)
	else:
		center_rect.size = Vector2.ONE * preview_px * 0.8
		center_rect.position = up - center_rect.size * 0.5
	var lines := RadialDots.wrap(_entry.display_label())
	var font := get_theme_default_font()
	for i in lines.size():
		var at := Vector2(middle.x - dead, middle.y + dead * 0.3 + i * (font_size + 1))
		draw_string_outline(
			font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, dead * 2.0, font_size, 4, text_outline
		)
		draw_string(
			font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, dead * 2.0, font_size, text_color
		)
