class_name StatBar
extends Control

## One stat bar of the wizard HUD (sacengine renderStatBar, renderer.d:4808-4826), drawn inside a
## 32×96-unit frame: a 32×68 area from y = 14 filled from the bottom by the `mid` strip, capped by the
## 4-unit `top` strip above the fill and the 6-unit `bottom` strip below it (both drawn even when empty,
## as in sacengine). The strips are `<strip_prefix>_{top,mid,bottom}.png` of assets/original/ui/hud
## (tools/import_ui.py); without them the fill is a flat `fallback_color` rectangle.

## Name prefix of the three strips in assets/original/ui/hud (`stat_mana`, `stat_health`).
@export var strip_prefix := "stat_mana"
## Fill colour when the strips are missing.
@export var fallback_color := Color8(0, 96, 192)
## Frame size in HUD units (the bar scales with the control's height).
@export var frame_units := Vector2(32.0, 96.0)
@export var area_top := 14.0
@export var area_height := 68.0
@export var top_cap := 4.0
@export var bottom_cap := 6.0

## Filled part, 0…1.
var fraction := 0.0:
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


## Screen pixels of the full fill area (68 units tall).
func full_height() -> float:
	return area_height * _unit()


func _unit() -> float:
	return size.y / frame_units.y


func _draw() -> void:
	var unit := _unit()
	var width := size.x
	var height := area_height * unit * fraction
	var y := (area_top + (1.0 - fraction) * area_height) * unit
	var mid := Rect2(0.0, y, width, height)
	if _top == null or _mid == null or _bottom == null:
		if height > 0.0:
			draw_rect(mid, fallback_color)
		return
	draw_texture_rect(_top, Rect2(0.0, y - top_cap * unit, width, top_cap * unit), false)
	if height > 0.0:
		draw_texture_rect(_mid, mid, false)
	draw_texture_rect(_bottom, Rect2(0.0, y + height, width, bottom_cap * unit), false)
