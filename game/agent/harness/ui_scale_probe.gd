extends Node

## Interface-size helper for flows (055h-1). It moves the shared size like the options slider does, without saving it
## (`set_scale(v, false)`: the player's user://settings.cfg is not touched), and reads back what the HUD did with it.
## It never reloads the scene.
##
##   set_ui(v)   UiScalePrefs.set_scale(v, false) on data/ui/ui_scale.tres; returns the size in use.
##   report()    fills `scale`, `canvas`, `gap_px`, `aim_px`, `cursor_px`, `expected_cursor_px` and `same`; returns the line.

const SHARED := preload("res://data/ui/ui_scale.tres")

## Interface size in use and the canvas it leaves (canvas pixels).
var scale := 0.0
var canvas := Vector2.ZERO
## Canvas pixels from the roster's bottom edge to the spell book's top (negative = overlap).
var gap_px := 0.0
## Side of the armed icon (canvas pixels) and of the hardware cursor (window pixels), and what the cursor should be.
var aim_px := 0.0
var cursor_px := 0
var expected_cursor_px := 0
## The roster clears the book by 4 canvas pixels and the cursor is within one pixel of its formula.
var same := false


func set_ui(value: float) -> float:
	SHARED.set_scale(value, false)
	return SHARED.get_scale()


func report() -> String:
	var scene := get_tree().current_scene
	var book_node := scene.find_child("SpellBook", true, false) as Control
	var roster_node := scene.find_child("SelectionRoster", true, false) as Control
	var aim := scene.find_child("Aim", true, false) as Control
	var skin := scene.find_child("CursorSkin", true, false) as CursorSkin
	if book_node == null or roster_node == null or aim == null or skin == null:
		return "missing nodes"
	scale = SHARED.get_scale()
	canvas = get_viewport().get_visible_rect().size
	aim_px = aim.size.x
	cursor_px = skin.applied_px
	expected_cursor_px = skin.physical_px()
	gap_px = book_node.get_global_rect().position.y - roster_node.get_global_rect().end.y
	same = gap_px >= 4.0 and absi(cursor_px - expected_cursor_px) <= 1
	var line := "ui=%.2f canvas=%s gap=%.1f aim=%.1f cursor=%d expected=%d same=%s" % [scale, canvas, gap_px, aim_px, cursor_px, expected_cursor_px, same]
	print("UI_SCALE_REPORT ", line)
	return line
