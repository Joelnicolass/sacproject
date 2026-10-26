@tool
class_name BrushCanvas
extends RefCounted

## What a brush stroke paints on: a grid of cells laid over the map (the ground's lattice vertices, a picture's pixels),
## the working copy a stroke changes, patches of one rect (before and after, for undo and redo), the preview while it is
## not saved, and saving to its file. Each kind is one subclass (LatticeCanvas; RolesCanvas and DensityCanvas for the
## pictures); this base does nothing and keeps the shared contract. Not: the mouse (BrushPainter), the bar, the undo
## history (TerrainHistory), the arithmetic (BrushRules, PaintRules).


## The bytes of one rect of a picture, row by row, `channels` bytes a pixel: enough to put that rect back exactly.
class PixelPatch extends RefCounted:
	var rect: Rect2i
	var bytes := PackedByteArray()

	## The bytes of `from` in a picture `width` pixels wide.
	static func read(data: PackedByteArray, width: int, channels: int, from: Rect2i) -> PixelPatch:
		var patch := PixelPatch.new()
		var kept := PackedByteArray()
		var row := from.size.x * channels
		for y in range(from.position.y, from.end.y):
			var start := (y * width + from.position.x) * channels
			kept.append_array(data.slice(start, start + row))
		patch.rect = from
		patch.bytes = kept
		return patch

	## Puts these bytes back into a picture `width` pixels wide (undo writes `before`, redo writes `after`).
	func write(data: PackedByteArray, width: int, channels: int) -> void:
		var row := rect.size.x * channels
		for k in rect.size.y:
			var start := ((rect.position.y + k) * width + rect.position.x) * channels
			for b in row:
				data[start + b] = bytes[k * row + b]


## The rect a list of patches covers (each has a `rect`: BrushStroke.Patch or PixelPatch); empty for none.
static func span(patches: Array) -> Rect2i:
	var out := Rect2i()
	for patch: Variant in patches:
		var rect: Rect2i = patch.rect
		out = out.merge(rect) if out.has_area() else rect
	return out


## The node an undo step of this canvas belongs to (a Terrain, a FloraLayer); null headless.
func context() -> Node:
	return null


## The cells a dab of reach `reach_m` centred on the ground point `center_m` (x, z in metres) may touch.
func cell_rect(_center_m: Vector2, _reach_m: float) -> Rect2i:
	return Rect2i()


## A stroke starts at `at_m` with `mode` (the canvas's own enum): it takes a fresh working copy, changes nothing yet.
func begin(_mode: int, _brush: TerrainBrush, _at_m: Vector2) -> void:
	pass


## One dab at `at_m` on the working copy; `vertical_px` is how far the mouse moved up since the last dab. What it touched.
func dab(_at_m: Vector2, _vertical_px: float) -> Rect2i:
	return Rect2i()


## A full copy of the working data (the stroke's "before").
func copy() -> Variant:
	return null


## The values of `rect` in the working data, or in `from` (a `copy()`).
func patch(_rect: Rect2i, _from: Variant = null) -> RefCounted:
	return null


## Undo and redo: writes `patches` in order, then shows them (preview or draft).
func write(_patches: Array) -> void:
	pass


## Shows `rect` of the working data on screen before it is saved.
func preview(_rect: Rect2i) -> void:
	pass


## True when this canvas holds changes its file does not have yet.
func is_dirty() -> bool:
	return false


## Writes the file and reimports it: "" or the error.
func save() -> String:
	return ""


## The undo history's name of a stroke with `mode`, in Spanish.
func label(_mode: int) -> String:
	return ""


## The res:// path of the file this canvas saves to ("" when it is not one picture), so a reimport reaches it.
func file() -> String:
	return ""


## Its file came back from a reimport: the preview goes, the imported file shows again.
func reloaded() -> void:
	pass
