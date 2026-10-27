@tool
class_name RolesCanvas
extends BrushCanvas

## Which kind of ground lies where, as a brush canvas: the map's ground_roles.png (Terrain.ground_roles, RGBA, a role a
## channel as GodGround.roles(): R open, G earth, B rock, A path; mode = channel). A dab adds its role keeping the sum 255
## (PaintRules.add_role); the editor shows it at once by uploading the working copy to the imported texture on the GPU
## (texture_2d_update, in the texture's format), so no node or material is touched (TerrainLayer stays their only writer).
## Ctrl+S writes the PNG (the `.import` stays) and reimports it. Headless (`over`) it paints its own Image.
## Not: the mouse, undo, the material, the arithmetic (PaintRules).

const CanvasFiles := preload("res://addons/terrain_tools/brush/canvas_files.gd")
const CHANNELS := 4
const LABELS := ["Roles: pasto", "Roles: tierra", "Roles: roca", "Roles: camino"]

var _terrain: Terrain
var _texture: Texture2D  ## the imported ground_roles this canvas paints (null headless)
var _work := PackedByteArray()  ## RGBA8, row by row; empty until the first stroke (or after a reimport)
var _size := Vector2i()
var _cell_m := TerrainGrid.CELL_M  ## metres a pixel covers: the picture spans the map's footprint
var _format := Image.FORMAT_RGBA8  ## what the GPU texture holds; the preview converts to it
var _compressed := false  ## the texture is VRAM-compressed: no live preview (it shows on save)
var _dirty := false
var _mode := 0
var _brush: TerrainBrush


## A canvas over a copy of `image` (any format; kept as RGBA8). No editor: `picture()` reads the result.
static func over(image: Image) -> RolesCanvas:
	var canvas := RolesCanvas.new()
	canvas._adopt(image)
	return canvas


## The editor's canvas of `terrain`'s ground_roles.png (it must have one).
static func of(terrain: Terrain) -> RolesCanvas:
	var canvas := RolesCanvas.new()
	canvas._terrain = terrain
	canvas._texture = terrain.ground_roles
	return canvas


## The Terrain that shows these roles now (TerrainHistory keeps one canvas per ground_roles texture).
func use(terrain: Terrain) -> void:
	_terrain = terrain


## The working copy as an Image (RGBA8).
func picture() -> Image:
	_load()
	return Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, _work)


func context() -> Node:
	return _terrain


func cell_rect(center_m: Vector2, reach_m: float) -> Rect2i:
	_load()
	return PaintRules.pixel_rect(center_m, reach_m, _cell_m, _size)


func begin(mode: int, brush: TerrainBrush, _at_m: Vector2) -> void:
	_load()
	_mode = clampi(mode, 0, CHANNELS - 1)
	_brush = brush


func dab(at_m: Vector2, _vertical_px: float) -> Rect2i:
	var rect := cell_rect(at_m, _brush.size_m)
	if rect.has_area():
		PaintRules.add_role(_work, _size.x, rect, PaintRules.weights(_brush, at_m, rect, _cell_m), _mode, _brush.flow)
	return rect


func copy() -> Variant:
	_load()
	return _work.duplicate()


func patch(rect: Rect2i, from: Variant = null) -> RefCounted:
	var source: PackedByteArray = _work if from == null else from
	return BrushCanvas.PixelPatch.read(source, _size.x, CHANNELS, rect)


## Undo and redo (TerrainHistory.write already skipped it if the Terrain is gone).
func write(patches: Array) -> void:
	_load()
	for each: BrushCanvas.PixelPatch in patches:
		each.write(_work, _size.x, CHANNELS)
	_dirty = _texture != null
	preview(BrushCanvas.span(patches))


## Uploads the whole working copy to the imported texture (256² RGBA is small). Not headless, not to a VRAM-compressed one.
func preview(_rect: Rect2i) -> void:
	if _texture == null or _work.is_empty() or _compressed or not _texture.get_rid().is_valid():
		return
	var image := picture()
	if image.get_format() != _format:
		image.convert(_format)
	RenderingServer.texture_2d_update(_texture.get_rid(), image, 0)


func is_dirty() -> bool:
	return _dirty


func save() -> String:
	var path := file()
	var error := CanvasFiles.save_png(picture(), path)
	if not error.is_empty():
		return error
	_dirty = false
	print("Roles: guardado %s" % path)
	CanvasFiles.reimport.call_deferred(PackedStringArray([path]))
	return ""


func label(mode: int) -> String:
	return LABELS[clampi(mode, 0, CHANNELS - 1)]


func file() -> String:
	return _texture.resource_path if _texture != null else ""


## The PNG came back from a reimport: the next stroke starts from it; strokes made since the save show again.
func reloaded() -> void:
	if not _dirty:
		_work = PackedByteArray()
		return
	var image := _texture.get_image()
	_format = image.get_format()
	_compressed = image.is_compressed()
	preview(Rect2i())


## Takes the working copy from the texture the first time (or after a reimport).
func _load() -> void:
	var image: Image = _texture.get_image() if _work.is_empty() and _texture != null else null
	if image == null:
		return
	_format = image.get_format()
	_compressed = image.is_compressed()
	if _compressed:
		push_warning("Roles: %s está comprimida en VRAM; la vista previa se ve al guardar." % file())
	_adopt(image)


func _adopt(image: Image) -> void:
	var rgba := image.duplicate() as Image
	if rgba.is_compressed():
		rgba.decompress()
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba.convert(Image.FORMAT_RGBA8)
	_size = rgba.get_size()
	_cell_m = TerrainGrid.SIZE_M / float(maxi(_size.x, 1))
	_work = rgba.get_data()
