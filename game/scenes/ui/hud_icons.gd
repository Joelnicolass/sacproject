class_name HudIcons
extends RefCounted

## Images the HUD draws from res://assets/original/ui/ (RFC-033d; `tools/import_ui.py` writes them, LFS). The
## 32×32 CRE8/SPEL icons and the HUD sheets (tabs, page, fram, spi2) are imported textures read with `load()`.
## Every lookup returns null when the file is missing, so each view draws its own fallback.
##
## RFC-025c adds the cursors of curs.FLDR (`cursor`) and the XMNU icons of xmenu.wad (`xmenu`); the
## order icons Matt/Mgua/Mgot and the invalid-target icon ncst are in `icons/` next to the rest.
##
## `icon_dir` / `hud_dir` / `cursor_dir` / `xmenu_dir` are static knobs: point them at an empty
## folder to rehearse the fallback.

const ICON_DIR := OriginalAssets.UI_ICONS_DIR
const HUD_DIR := OriginalAssets.UI_HUD_DIR
const CURSOR_DIR := OriginalAssets.UI_CURSORS_DIR
const XMENU_DIR := OriginalAssets.UI_XMENU_DIR

static var icon_dir := ICON_DIR
static var hud_dir := HUD_DIR
static var cursor_dir := CURSOR_DIR
static var xmenu_dir := XMENU_DIR

static var _icons: Dictionary = {}
static var _sheets: Dictionary = {}
static var _cursors: Dictionary = {}
static var _xmenu: Dictionary = {}
static var _scaled: Dictionary = {}


## The CRE8/SPEL icon `<tag>.png` (a creature, spell or ability), or null.
static func icon(tag: String) -> Texture2D:
	if tag.is_empty():
		return null
	var key := icon_dir + tag
	if not _icons.has(key):
		_icons[key] = _load_png(icon_dir + tag + ".png")
	return _icons[key]


## A whole HUD sheet (`tabs`, `page`, `fram`, `spi2`), or null.
static func sheet(sheet_name: String) -> Texture2D:
	var key := hud_dir + sheet_name
	if not _sheets.has(key):
		_sheets[key] = _load_png(hud_dir + sheet_name + ".png")
	return _sheets[key]


## A sub-rectangle of a sheet (pixels), or null.
static func region(sheet_name: String, rect: Rect2) -> Texture2D:
	var source := sheet(sheet_name)
	if source == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = rect
	return atlas


## A cursor of curs.FLDR (`Cnor`, `Cfun`, `Tnme`…), or null.
static func cursor(cursor_name: String) -> Texture2D:
	if cursor_name.is_empty():
		return null
	var key := cursor_dir + cursor_name
	if not _cursors.has(key):
		_cursors[key] = _load_png(cursor_dir + cursor_name + ".png")
	return _cursors[key]


## The cursor resized to `size_px` square (the hardware cursor takes at most 256), or null.
static func cursor_sized(cursor_name: String, size_px: int) -> Texture2D:
	var key := "%s%s@%d" % [cursor_dir, cursor_name, size_px]
	if not _scaled.has(key):
		var texture := cursor(cursor_name)
		var scaled: Texture2D = null
		if texture != null:
			var image := texture.get_image()
			if image != null and not image.is_empty():
				if image.get_width() != size_px or image.get_height() != size_px:
					image = image.duplicate()
					image.resize(size_px, size_px, Image.INTERPOLATE_BILINEAR)
				scaled = ImageTexture.create_from_image(image)
		_scaled[key] = scaled
	return _scaled[key]


## The icon of an XMNU (`zwp1`: retreat), or null.
static func xmenu(tag: String) -> Texture2D:
	if tag.is_empty():
		return null
	var key := xmenu_dir + tag
	if not _xmenu.has(key):
		_xmenu[key] = _load_png(xmenu_dir + tag + ".png")
	return _xmenu[key]


## What an armed order shows: an icon of `icons/` (spell, ability, structure, Matt, Mgua, Mgot) or,
## failing that, the XMNU of that tag.
static func armed(tag: String) -> Texture2D:
	var texture := icon(tag)
	return texture if texture != null else xmenu(tag)


## Forgets what was loaded (after changing the folders).
static func reset() -> void:
	_icons.clear()
	_sheets.clear()
	_cursors.clear()
	_xmenu.clear()
	_scaled.clear()


static func _load_png(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
