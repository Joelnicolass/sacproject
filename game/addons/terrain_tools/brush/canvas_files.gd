@tool
extends RefCounted

## The editor's file work for the pictures a brush paints: a blank PNG with its `.import` (lossless, no mipmaps, no alpha
## border fix, never recompressed for 3D, no uid line: the editor gives it one), saving an Image as PNG, and telling the
## editor's file system that files changed so it imports them again. It reaches the editor dynamically, so the canvases
## that use it still load headless (where `filesystem()` is null and reimporting does nothing).
## Not: what a pixel means (the canvases), undo, the heights pictures' format (MapImages).

## The `.import` every picture made here gets: what ground_roles.png and the flora densities need to stay exact.
const IMPORT := """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="%s"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


## The editor's EditorFileSystem, or null when no editor runs (headless cases, the game). The singleton is registered
## in every process, but outside the editor asking for it is an error: `is_editor_hint` tells which one this is.
static func filesystem() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return null
	var editor: Object = Engine.get_singleton(&"EditorInterface")
	return editor.get_resource_filesystem()


## Writes a `size` picture of `format` filled with `fill` at `path` (res://), and its `.import` if it has none.
## "" or the error.
static func blank(path: String, size: Vector2i, format: Image.Format, fill: Color) -> String:
	var image := Image.create_empty(size.x, size.y, false, format)
	image.fill(fill)
	var error := save_png(image, path)
	return error if not error.is_empty() else write_import(path)


## Writes the fixed `.import` beside `path` unless one is there. "" or the error.
static func write_import(path: String) -> String:
	var import_path := path + ".import"
	if FileAccess.file_exists(import_path):
		return ""
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if file == null:
		return "No se pudo escribir %s (%s)." % [import_path, error_string(FileAccess.get_open_error())]
	file.store_string(IMPORT % path)
	file.close()
	return ""


## Saves `image` as a PNG at `path` (res://). "" or the error.
static func save_png(image: Image, path: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error := image.save_png(path)
	return "" if error == OK else "No se pudo escribir %s (%s)." % [path, error_string(error)]


## Tells the editor every file of `paths` changed (gone ones too) and imports again the ones that exist, in that order.
static func reimport(paths: PackedStringArray) -> void:
	var files: Object = filesystem()
	if files == null:
		return
	var stale := PackedStringArray()
	for path in paths:
		files.update_file(path)
		if FileAccess.file_exists(path):
			stale.append(path)
	if not stale.is_empty():
		files.reimport_files(stale)
