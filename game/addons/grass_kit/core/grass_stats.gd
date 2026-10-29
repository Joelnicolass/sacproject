@tool
class_name GrassStats
extends RefCounted

## What a field draws now. `blades` are instanced (every vertex shader runs, twice with a depth
## prepass); `blades_in_view` are in the cells the camera sees, the ones the GPU pays for. The
## shader thins many of them further by distance. `draws` are the draw calls in view: one per kind
## of blade per cell, so each kind added to a look adds a draw per cell.

var cells := 0
var blades := 0
var cells_in_view := 0
var blades_in_view := 0
var draws := 0
## Blades in view of each kind of the look, in its order.
var blades_by_kind := PackedInt32Array()


func _to_string() -> String:
	return "%d cells, %d blades; in view %d cells, %d blades, %d draws" % [
		cells, blades, cells_in_view, blades_in_view, draws
	]
