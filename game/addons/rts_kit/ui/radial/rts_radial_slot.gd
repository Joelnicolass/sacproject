@tool
class_name RtsRadialSlot
extends Control

## One icon of a radial ring: the picture and a glow. It knows nothing about the menu. The hovered
## icon grows and glows, the others dim while something is hovered. An entry with no picture is drawn:
## a formation as its dots, anything else as its name (two lines when it has a space).

@export var icon_rect: TextureRect
@export var highlight: Control
@export_group("Hover")
@export var hover_s := 0.12
@export var highlight_scale := 1.3
@export var idle_tint := Color(0.88, 0.88, 0.92, 1.0)
@export var dim_tint := Color(0.5, 0.5, 0.56, 0.75)
@export_group("Fallback")
@export var fallback_color := Color(0.95, 0.95, 0.98, 1.0)
@export var fallback_outline := Color(0, 0, 0, 1)
@export_range(6, 24) var fallback_font_size := 10

var entry: RtsMenuEntry

var _tween: Tween


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if icon_rect != null and highlight != null
		else PackedStringArray(["Assign icon_rect and highlight."])
	)


func setup(value: RtsMenuEntry, size_px: float) -> void:
	entry = value
	custom_minimum_size = Vector2.ONE * size_px
	size = Vector2.ONE * size_px
	pivot_offset = size * 0.5
	icon_rect.texture = value.display_icon()
	set_state(false, false, false)
	queue_redraw()


## `hovered`: the pointer is on this entry. `dimmed`: it is on another one. `animate` false snaps
## (opening, editor).
func set_state(hovered: bool, dimmed: bool, animate := true) -> void:
	var tint := Color.WHITE if hovered else (dim_tint if dimmed else idle_tint)
	var grown := Vector2.ONE * (highlight_scale if hovered else 1.0)
	var glow := 1.0 if hovered else 0.0
	if _tween:
		_tween.kill()
	if not animate or not is_inside_tree() or Engine.is_editor_hint():
		scale = grown
		icon_rect.modulate = tint
		highlight.modulate.a = glow
		highlight.visible = hovered
		return
	highlight.visible = true
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", grown, hover_s)
	_tween.tween_property(icon_rect, "modulate", tint, hover_s)
	_tween.tween_property(highlight, "modulate:a", glow, hover_s)


func _draw() -> void:
	if entry == null or icon_rect.texture != null:
		return
	var middle := size * 0.5
	if entry.formation != null:
		RtsRadialDots.draw(
			self, entry.formation, middle, size.x * 0.62, 2.2, fallback_color, fallback_outline
		)
		return
	var lines := RtsRadialDots.wrap(tr(entry.display_label()))
	var font := get_theme_default_font()
	var line_height := fallback_font_size + 1.0
	var top := middle.y - 0.5 * line_height * (lines.size() - 1) + fallback_font_size * 0.35
	for i in lines.size():
		var at := Vector2(-size.x * 0.5, top + i * line_height)
		draw_string_outline(
			font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x * 2.0, fallback_font_size, 4,
			fallback_outline
		)
		draw_string(
			font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x * 2.0, fallback_font_size,
			fallback_color
		)
