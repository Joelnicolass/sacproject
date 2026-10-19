class_name BitmapDigits
extends RefCounted

## Draws short texts (the soul count) with a SacFont sheet such as `fn10.png`: a 16×16 grid of glyphs,
## each as wide as its rightmost non-transparent column + 1, advancing width + 1 (sacfont.d:24-60, 70-80).
## Size of a text = (Σ advance, line height) · scale (sacfont.d getSize). Pure helper: no state but the
## per-sheet width table.

const GRID := 16
## SacFont.lineHeight for fn10 (sacfont.d:57).
const LINE_HEIGHT := 14
## fn10 space (sacfont.d:43).
const SPACE_WIDTH := 6

static var _widths: Dictionary = {}


## Glyph widths of `font` (256 entries), read once from its alpha.
static func widths(font: Texture2D) -> PackedInt32Array:
	var key := font.get_instance_id()
	if _widths.has(key):
		return _widths[key]
	var result := PackedInt32Array()
	result.resize(256)
	var image := font.get_image()
	if image != null and not image.is_empty():
		var cell := Vector2i(image.get_width() / GRID, image.get_height() / GRID)
		for k in 256:
			var u := (k % GRID) * cell.x
			var v := (k / GRID) * cell.y
			var right := 0
			for i in cell.x:
				for j in cell.y:
					if image.get_pixel(u + i, v + j).a > 0.0:
						right = maxi(right, i)
			result[k] = right + 1
		result[32] = SPACE_WIDTH
	_widths[key] = result
	return result


## Screen size of `text` at `scale` pixels per font pixel.
static func size_of(font: Texture2D, text: String, scale: float) -> Vector2:
	var table := widths(font)
	var width := 0
	for c in text.to_ascii_buffer():
		width += table[c] + 1
	return Vector2(width, LINE_HEIGHT) * scale


## Draws `text` with its top-left at `top_left`, tinted `color` (the glyphs are white).
static func draw(canvas: CanvasItem, font: Texture2D, text: String, top_left: Vector2, scale: float, color: Color) -> void:
	var table := widths(font)
	var cell := font.get_size() / GRID
	var cursor := 0.0
	for c in text.to_ascii_buffer():
		var width := float(table[c])
		# sacengine pads each glyph with widthSlack transparent columns; drawing the glyph alone looks the same.
		var source := Rect2((c % GRID) * cell.x, (c / GRID) * cell.y, width, cell.y)
		var dest := Rect2(top_left + Vector2(cursor, 0.0), Vector2(width, cell.y) * scale)
		canvas.draw_texture_rect_region(font, dest, source, color)
		cursor += (width + 1.0) * scale
