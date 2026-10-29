@tool
class_name BuildAreaLook
extends Resource

## How the ring on the ground around a manafount looks while a structure spell aims at it: one
## colour when the tower can rise there, another when it cannot, and how wide the line is. Every
## ring that shares this file changes at once, in the editor too. It does not decide when the ring
## shows (ArmedPreview) nor its radius (the BuildArea shape).

## The tower can rise here.
@export var ok_color := Color(0.35, 0.95, 0.45, 0.85):
	set(value):
		ok_color = value
		emit_changed()
## The cast would be refused (too far, no mana, a building on the spot, the fount already has a
## tower).
@export var blocked_color := Color(0.95, 0.22, 0.16, 0.85):
	set(value):
		blocked_color = value
		emit_changed()
## Width of the line, in metres, measured inwards from the edge of the area.
@export_range(0.05, 5.0, 0.05, "suffix:m") var width_m := 0.8:
	set(value):
		width_m = value
		emit_changed()
