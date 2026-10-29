class_name BrushStroke
extends RefCounted

## One drag of a brush, from press to release, on any BrushCanvas (the ground's lattice, a picture): the canvas's mode,
## the rect of cells touched so far and a copy of the canvas as it was, so `finish()` hands back the exact before and after
## of that rect for undo and redo. What a dab does is the canvas's (LatticeCanvas for the ground). Not: editor input, the
## undo history, the mesh refresh. No editor API: it runs headless.

## What a drag does. Lower is RAISE dragged down; FLATTEN is Shift + smooth; FILL is Shift + void.
enum Mode { RAISE, SMOOTH, FLATTEN, VOID, FILL }

## One smoothing drag is one full pass (each vertex's weight still scales it).
const PASS_STRENGTH := 1.0


## The ground inside one rect of vertices (heights and voids, row by row), enough to put that rect back exactly.
class Patch extends RefCounted:
	var rect: Rect2i
	var heights_m := PackedFloat32Array()
	var void_mask := PackedByteArray()

	## The values of `rect` in these lattice arrays.
	static func read(heights: PackedFloat32Array, mask: PackedByteArray, from: Rect2i) -> Patch:
		var patch := Patch.new()
		var patch_heights := PackedFloat32Array()
		var patch_mask := PackedByteArray()
		for id in BrushRules.ids(from):
			patch_heights.append(heights[id])
			patch_mask.append(mask[id])
		patch.rect = from
		patch.heights_m = patch_heights
		patch.void_mask = patch_mask
		return patch

	## Puts these values back into the lattice arrays (undo writes `before`, redo writes `after`).
	func write(heights: PackedFloat32Array, mask: PackedByteArray) -> void:
		var vertices := BrushRules.ids(rect)
		for i in vertices.size():
			heights[vertices[i]] = heights_m[i]
			mask[vertices[i]] = void_mask[i]


## The canvas's mode (BrushStroke.Mode on the lattice).
var mode := 0
## What this stroke paints on.
var canvas: BrushCanvas

var _before: Variant
var _rect := Rect2i()
var _touched := false


## Starts a stroke on `on` at the ground point `at` (x, z in metres). It changes nothing yet: the caller calls `drag()`
## right away for the press itself.
func begin(on: BrushCanvas, stroke_mode: int, brush: TerrainBrush, at: Vector2) -> void:
	canvas = on
	mode = stroke_mode
	canvas.begin(stroke_mode, brush, at)
	_before = canvas.copy()
	_rect = Rect2i()
	_touched = false


## One dab at `at` (x, z in metres). `vertical_px` is how far the mouse moved up since the last dab (negative = down);
## only raising uses it.
func drag(at: Vector2, vertical_px: float) -> void:
	var rect := canvas.dab(at, vertical_px)
	_rect = _rect.merge(rect) if _touched else rect
	_touched = true


## The cells touched so far (empty before the first dab).
func dirty_rect() -> Rect2i:
	return _rect


## Ends the stroke: `{rect: Rect2i, before: Array, after: Array}`, one patch each for the touched rect.
func finish() -> Dictionary:
	var result := {"rect": _rect, "before": [canvas.patch(_rect, _before)], "after": [canvas.patch(_rect)]}
	_before = null
	return result
