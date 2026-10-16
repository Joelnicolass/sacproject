class_name SoulCounter
extends Control

## The soul panel of the wizard HUD (sacengine renderStats + renderText, renderer.d:4786-4797,
## 5306-5344): the blue soul of `spir.png` (4×4 grid, blue = cells 0–7) spinning at 15 frames a second,
## 85 % of the 64×96-unit frame, and the soul count in the middle with the `fn10` font, black shadow
## then white half a unit up-left. Presentation only: the clock runs in `_process`.
## Without the cache the soul is not drawn and the count falls back to `%Count` (a Label).

@export var soul_sheet := "spir"
@export var font_sheet := "fn10"
## Grid of the soul sheet and the cells of the blue soul.
@export var columns := 4
@export var first_frame := 0
@export var frame_count := 8
## SacSoul.numFrames / 2 per second at 30 updates (dagonBackend.d:1620): 8 frames in ~0.53 s.
@export var fps := 15.0
## Soul size relative to the frame (renderStats: 0.85).
@export var soul_fill := 0.85
## Frame size in HUD units (font and soul scale with the control's height).
@export var frame_units := Vector2(64.0, 96.0)
@export var text_color := Color.WHITE
@export var shadow_color := Color.BLACK

## Souls shown.
var souls := 0:
	set(value):
		if value == souls:
			return
		souls = value
		_update_fallback()
		queue_redraw()
## Current cell of the blue soul (0…frame_count-1).
var frame := 0
## Frames advanced since ready (for measuring the animation speed).
var frames_played := 0

var _soul: Texture2D
var _font: Texture2D
var _clock := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_soul = HudIcons.sheet(soul_sheet)
	_font = HudIcons.sheet(font_sheet)
	resized.connect(queue_redraw)
	_update_fallback()


func _process(delta: float) -> void:
	if _soul == null or fps <= 0.0:
		return
	_clock += delta
	var step := 1.0 / fps
	if _clock < step:
		return
	var advance := int(_clock / step)
	_clock -= advance * step
	frame = (frame + advance) % frame_count
	frames_played += advance
	queue_redraw()


func _update_fallback() -> void:
	var count := get_node_or_null("%Count") as Label
	if count == null:
		return
	count.visible = _font == null
	count.text = str(souls)


func _draw() -> void:
	var unit := size.y / frame_units.y
	var center := size * 0.5
	if _soul != null:
		var cell := _soul.get_size() / columns
		var index := first_frame + frame
		var source := Rect2(Vector2(index % columns, index / columns) * cell, cell)
		var soul_size := size * soul_fill
		draw_texture_rect_region(_soul, Rect2(center - soul_size * 0.5, soul_size), source)
	if _font != null:
		var text := str(souls)
		var text_size := BitmapDigits.size_of(_font, text, unit)
		BitmapDigits.draw(self, _font, text, center - text_size * 0.5, unit, shadow_color)
		BitmapDigits.draw(self, _font, text, center - (text_size + Vector2(unit, unit)) * 0.5, unit, text_color)
