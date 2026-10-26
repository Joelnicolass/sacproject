class_name BrushStroke
extends RefCounted

## One drag of a ground brush, from press to release: what the tool is, the height under the press (flatten aims at it),
## the rect of vertices touched so far and the ground as it was, so `finish()` hands back the exact before and after of
## that rect for undo and redo. It edits the arrays it was given IN PLACE (the caller's, shared). Not: editor input, the
## undo history (the plugin keeps the patches), the mesh refresh. No editor API: it runs headless.

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


var mode := Mode.RAISE
## The height of the vertex nearest to where the stroke began.
var start_height_m := 0.0

var _brush: TerrainBrush
var _heights: PackedFloat32Array
var _mask: PackedByteArray
var _heights_before: PackedFloat32Array
var _mask_before: PackedByteArray
var _rect := Rect2i()
var _touched := false


## Starts a stroke at the ground point `at` (x, z in metres) on these lattice arrays. It changes nothing yet: the caller
## calls `drag()` right away for the press itself.
func begin(heights: PackedFloat32Array, mask: PackedByteArray, stroke_mode: Mode, brush: TerrainBrush, at: Vector2) -> void:
	_heights = heights
	_mask = mask
	_heights_before = heights.duplicate()
	_mask_before = mask.duplicate()
	mode = stroke_mode
	_brush = brush
	start_height_m = heights[TerrainGrid.vertex_id(at.x, at.y)]
	_rect = Rect2i()
	_touched = false


## One dab at `at` (x, z in metres). `vertical_px` is how far the mouse moved up since the last dab (negative = down);
## only RAISE uses it.
func drag(at: Vector2, vertical_px: float) -> void:
	var rect := TerrainGrid.vertex_rect(at, _brush.size_m)
	var weights := BrushRules.weights(_brush, at, rect)
	match mode:
		Mode.RAISE:
			BrushRules.raise(_heights, rect, weights, vertical_px * _brush.strength_m)
		Mode.SMOOTH:
			BrushRules.smooth(_heights, rect, weights, PASS_STRENGTH)
		Mode.FLATTEN:
			BrushRules.flatten(_heights, rect, weights, start_height_m)
		Mode.VOID:
			BrushRules.paint_void(_mask, rect, weights, true)
		Mode.FILL:
			BrushRules.paint_void(_mask, rect, weights, false)
	_rect = _rect.merge(rect) if _touched else rect
	_touched = true


## The vertices touched so far (empty before the first dab).
func dirty_rect() -> Rect2i:
	return _rect


## Ends the stroke: `{rect: Rect2i, before: Patch, after: Patch}` for the touched rect.
func finish() -> Dictionary:
	var result := {
		"rect": _rect,
		"before": Patch.read(_heights_before, _mask_before, _rect),
		"after": Patch.read(_heights, _mask, _rect),
	}
	_heights_before = PackedFloat32Array()
	_mask_before = PackedByteArray()
	return result

