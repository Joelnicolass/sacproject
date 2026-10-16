extends Node

## F84 helper: changes the shared HUD size while the match runs, like a future options menu, without
## saving it (`set_scale(v, false)`: the player's user://settings.cfg is not touched), and reads back
## what the four HUD nodes did with it. It never reloads the scene.
##
##   set_hud(v)   HudScale.set_scale(v, false) on data/ui/hud_scale.tres; returns the scale in use.
##   report()     fills `book`, `roster`, `aim_px`, `cursor_px`, `gap_px` and `same`; returns the line.

const SHARED := preload("res://data/ui/hud_scale.tres")

## Scale of the spell book and the roster (x), the armed icon side and the cursor side.
var book := 0.0
var roster := 0.0
var aim_px := 0.0
var cursor_px := 0
## Screen pixels from the roster's bottom edge to the spell book's top (negative = overlap).
var gap_px := 0.0
## The roster uses the shared factor (or the smaller fitted one), the icon and the cursor one side,
## and the roster does not overlap the book.
var same := false


func set_hud(value: float) -> float:
	SHARED.set_scale(value, false)
	return SHARED.get_scale()


func report() -> String:
	var scene := get_tree().current_scene
	var book_node := scene.find_child("SpellBook", true, false) as Control
	var roster_node := scene.find_child("SelectionRoster", true, false) as Control
	var aim := scene.find_child("Aim", true, false) as Control
	var skin := scene.find_child("CursorSkin", true, false)
	if book_node == null or roster_node == null or aim == null or skin == null:
		return "missing nodes"
	book = book_node.scale.x
	roster = roster_node.scale.x
	aim_px = aim.size.x
	cursor_px = int(skin.get("_applied_px"))
	gap_px = book_node.get_global_rect().position.y - roster_node.get_global_rect().end.y
	var fitted := roster <= book + 0.0001 and is_equal_approx(roster, float(roster_node.get("fitted_factor")))
	same = fitted and is_equal_approx(aim_px, float(cursor_px)) and gap_px >= 0.0
	var line := "hud=%.2f book=%.3f roster=%.3f gap=%.1f aim=%.1f cursor=%d same=%s" % [SHARED.get_scale(), book, roster, gap_px, aim_px, cursor_px, same]
	print("HUD_SCALE_REPORT ", line)
	return line
