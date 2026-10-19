@tool
class_name HealthStrip
extends Control

## RFC-053 053e (F374): a horizontal health bar made of the HUD's vertical strips (`<strip_prefix>_{top,mid,bottom}.png` of
## assets/original/ui/hud, the ones StatBar stands up). They are drawn turned a quarter, so the strip's bottom is the bar's left
## end: the `bottom` cap on the left, the `mid` fill to the right, the `top` cap where the fill ends. The empty part is
## `empty_color`. Without the strips the fill is a flat `fallback_color` rectangle.

@export var strip_prefix := "stat_health"
@export var fallback_color := Color8(192, 24, 24)
@export var empty_color := Color(0.0, 0.0, 0.0, 0.55)
## Cap lengths as a share of the bar's thickness (the strips are 32 wide, the caps 6 and 4 long).
@export var bottom_cap_ratio := 6.0 / 32.0
@export var top_cap_ratio := 4.0 / 32.0

## Filled part, 0…1.
@export_range(0.0, 1.0) var fraction := 1.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, fraction):
			return
		fraction = value
		queue_redraw()

var _top: Texture2D
var _mid: Texture2D
var _bottom: Texture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_top = HudIcons.sheet(strip_prefix + "_top")
	_mid = HudIcons.sheet(strip_prefix + "_mid")
	_bottom = HudIcons.sheet(strip_prefix + "_bottom")
	resized.connect(queue_redraw)


func _draw() -> void:
	var length := size.x
	var thick := size.y
	draw_rect(Rect2(Vector2.ZERO, size), empty_color)
	var bottom := bottom_cap_ratio * thick
	var top := top_cap_ratio * thick
	var fill := maxf(length - bottom - top, 0.0) * fraction
	if _top == null or _mid == null or _bottom == null:
		if fill > 0.0:
			draw_rect(Rect2(0.0, 0.0, bottom + fill + top, thick), fallback_color)
		return
	# Turned +90°: the strip's x runs down the bar's thickness and its y runs from the bar's right end to its left end.
	draw_set_transform(Vector2(length, 0.0), PI * 0.5)
	draw_texture_rect(_bottom, Rect2(0.0, length - bottom, thick, bottom), false)
	if fill > 0.0:
		draw_texture_rect(_mid, Rect2(0.0, length - bottom - fill, thick, fill), false)
	draw_texture_rect(_top, Rect2(0.0, length - bottom - fill - top, thick, top), false)
	draw_set_transform(Vector2.ZERO, 0.0)
