extends SceneTree

## Builds the derived HUD sheets the Theme draws (scenes/ui/theme.tres, variations `Hud*`) from the
## sheets that are already in git (assets/original/ui/hud/fram.png and the six
## stat_*_{top,mid,bottom}.png), so the HUD frames and bars are whole images a StyleBoxTexture can
## draw without code. It does NOT need the original game; without that folder it only warns.
##
##   Godot --headless --path . --script res://tools/bake/hud_sheets.gd
##
## Writes next to the sources: stats_frame, soul_frame, roster_frame, minimap_frame, book_cap,
## stat_mana_bar, stat_health_bar, health_strip (.png) and fn10.fnt (the soul-count font: each glyph
## is as wide as its ink, as in the original). Every step is a copy, a flip, a quarter turn or a
## nearest-row pick, so the result is the same in any tool that follows these steps.

const DIR := "res://assets/original/ui/hud/"
## A bar's end caps are drawn ×1.2 (the HUD is laid out in 1280×720 canvas pixels, the original at
## 600): 4 → 5 and 6 → 7 rows.
const CAP_TOP_ROWS := 5
const CAP_BOTTOM_ROWS := 7
## The horizontal health strip of the target box is 16.8 px thick: its caps are 3 and 2 columns long
## (6 and 4 at 32 thick).
const STRIP_CAP_BOTTOM := 3
const STRIP_CAP_TOP := 2
const GLYPH_GRID := 16
const LINE_HEIGHT := 14
const SPACE_WIDTH := 6


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path(DIR)
	if not FileAccess.file_exists(folder + "fram.png"):
		push_warning(
			(
				# gdlint: ignore=max-line-length
				"hud_sheets: %s has no fram.png; nothing written (the sheets in git are used as they are)."
				% folder
			)
		)
		quit(0)
		return
	var fram := _load(folder, "fram")
	_save(
		_vertical_pair(
			fram.get_region(Rect2i(64, 0, 31, 31)), fram.get_region(Rect2i(64, 1, 31, 30))
		),
		folder,
		"stats_frame"
	)
	_save(
		_vertical_pair(
			fram.get_region(Rect2i(64, 0, 31, 31)), fram.get_region(Rect2i(64, 1, 31, 30))
		),
		folder,
		"soul_frame"
	)
	_save(_roster(fram.get_region(Rect2i(0, 0, 64, 128))), folder, "roster_frame")
	_save(_quarters(fram.get_region(Rect2i(64, 64, 64, 64))), folder, "minimap_frame")
	var cap := fram.get_region(Rect2i(80, 32, 48, 16))
	cap.rotate_90(CLOCKWISE)
	_save(cap, folder, "book_cap")
	for stat in ["mana", "health"]:
		var stack := _stack(folder, "stat_" + stat, CAP_TOP_ROWS, CAP_BOTTOM_ROWS)
		_save(stack, folder, "stat_%s_bar" % stat)
	# The strip lies down: its last row (the bottom cap) is the bar's left end, a clockwise quarter
	# turn.
	var strip := _stack(folder, "stat_health", STRIP_CAP_TOP, STRIP_CAP_BOTTOM)
	strip.rotate_90(CLOCKWISE)
	_save(strip, folder, "health_strip")
	_write_font(_load(folder, "fn10"), folder + "fn10.fnt")
	print("hud_sheets: 8 sheets and fn10.fnt written to %s" % folder)
	quit(0)


func _load(folder: String, sheet: String) -> Image:
	var image := Image.load_from_file(folder + sheet + ".png")
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, folder: String, sheet: String) -> void:
	var error := image.save_png(folder + sheet + ".png")
	if error != OK:
		push_error("hud_sheets: cannot write %s.png (%d)" % [sheet, error])


## `top` over `bottom` flipped upside down: the stats frame (the art is symmetric top to bottom).
func _vertical_pair(top: Image, bottom: Image) -> Image:
	var out := Image.create_empty(
		top.get_width(), top.get_height() + bottom.get_height(), false, Image.FORMAT_RGBA8
	)
	bottom.flip_y()
	out.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	out.blit_rect(bottom, Rect2i(Vector2i.ZERO, bottom.get_size()), Vector2i(0, top.get_height()))
	return out


## The left half of `fram` mirrored left-right, then the same row mirrored top-bottom: the whole
## selection frame.
func _roster(half: Image) -> Image:
	var side := half.get_width()
	var row := Image.create_empty(side * 2, half.get_height(), false, Image.FORMAT_RGBA8)
	var mirrored := half.duplicate() as Image
	mirrored.flip_x()
	row.blit_rect(mirrored, Rect2i(Vector2i.ZERO, half.get_size()), Vector2i.ZERO)
	row.blit_rect(half, Rect2i(Vector2i.ZERO, half.get_size()), Vector2i(side, 0))
	return _vertical_pair(row, row.duplicate() as Image)


## One quarter of the minimap ring in the top-left; the other three are its mirrors.
func _quarters(quarter: Image) -> Image:
	var side := quarter.get_width()
	var out := Image.create_empty(side * 2, side * 2, false, Image.FORMAT_RGBA8)
	for corner in 4:
		var piece := quarter.duplicate() as Image
		if corner % 2 == 1:
			piece.flip_x()
		if corner >= 2:
			piece.flip_y()
		out.blit_rect(
			piece,
			Rect2i(Vector2i.ZERO, quarter.get_size()),
			Vector2i((corner % 2) * side, (corner / 2) * side)
		)
	return out


## `<name>_top`, `<name>_mid` and `<name>_bottom` stacked in that order, the caps shortened or
## lengthened to the given rows by picking the nearest source row (no blending, so the result is
## exact).
func _stack(folder: String, sheet: String, top_rows: int, bottom_rows: int) -> Image:
	var top := _rows(_load(folder, sheet + "_top"), top_rows)
	var mid := _load(folder, sheet + "_mid")
	var bottom := _rows(_load(folder, sheet + "_bottom"), bottom_rows)
	var width := mid.get_width()
	var out := Image.create_empty(
		width, top_rows + mid.get_height() + bottom_rows, false, Image.FORMAT_RGBA8
	)
	out.blit_rect(top, Rect2i(Vector2i.ZERO, top.get_size()), Vector2i.ZERO)
	out.blit_rect(mid, Rect2i(Vector2i.ZERO, mid.get_size()), Vector2i(0, top_rows))
	out.blit_rect(
		bottom, Rect2i(Vector2i.ZERO, bottom.get_size()), Vector2i(0, top_rows + mid.get_height())
	)
	return out


func _rows(source: Image, rows: int) -> Image:
	var out := Image.create_empty(source.get_width(), rows, false, Image.FORMAT_RGBA8)
	for row in rows:
		var from := (2 * row + 1) * source.get_height() / (2 * rows)
		out.blit_rect(source, Rect2i(0, from, source.get_width(), 1), Vector2i(0, row))
	return out


## A BMFont text file for the 16×16 glyph sheet: each glyph is as wide as its rightmost inked column
## + 1 and advances one more.
func _write_font(sheet: Image, path: String) -> void:
	var cell := sheet.get_width() / GLYPH_GRID
	var lines := PackedStringArray()
	(
		lines
		. append(
			(
				# gdlint: ignore=max-line-length
				'info face="fn10" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0'
				% LINE_HEIGHT
			)
		)
	)
	lines.append(
		(
			"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
			% [LINE_HEIGHT, LINE_HEIGHT, sheet.get_width(), sheet.get_height()]
		)
	)
	lines.append('page id=0 file="fn10.png"')
	lines.append("chars count=95")
	for code in range(32, 127):
		var origin := Vector2i((code % GLYPH_GRID) * cell, (code / GLYPH_GRID) * cell)
		var width := SPACE_WIDTH if code == 32 else _ink_width(sheet, origin, cell)
		(
			lines
			. append(
				(
					# gdlint: ignore=max-line-length
					"char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
					% [code, origin.x, origin.y, width, cell, width + 1]
				)
			)
		)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("hud_sheets: cannot write %s" % path)
		return
	file.store_string("\n".join(lines) + "\n")


func _ink_width(sheet: Image, origin: Vector2i, cell: int) -> int:
	var right := 0
	for i in cell:
		for j in cell:
			if sheet.get_pixel(origin.x + i, origin.y + j).a > 0.0:
				right = maxi(right, i)
	return right + 1
