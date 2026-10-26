@tool
class_name DensityCanvas
extends BrushCanvas

## A FloraLayer's density picture (L8 PNG, 1 px = the layer's cell_m, white = max_per_cell plants) as a brush canvas: a dab
## moves its pixels toward the brush's density (PAINT) or to 0 (ERASE) with the brush's flow (PaintRules.toward). In the
## editor `preview` hands the working picture to the layer (FloraLayer.show_painting: the flora of that area replants
## live) until `save` writes the PNG and reimports it; `create_picture` makes the blank picture of a layer that has none.
## Headless (`over`) it edits the given bytes IN PLACE. Not: planting (FloraField, MeshPlanter), the mouse, undo.

const CanvasFiles := preload("res://addons/terrain_tools/brush/canvas_files.gd")
## A dab paints flora (toward the brush's density) or erases it (to 0, Shift).
enum Mode { PAINT, ERASE }
const LABELS := ["Flora: pintar", "Flora: borrar"]
## The undo step that gives a layer its new picture (TerrainHistory.density).
const NEW_PICTURE := "Flora: imagen nueva"
const FOLDER := "flora"

var _layer: FloraLayer  ## null headless
var _path := ""  ## the PNG this canvas saves to
var _size := Vector2i()
var _cell_m := 8.0
var _work := PackedByteArray()  ## L8, row by row (headless: the caller's bytes)
var _mode := Mode.PAINT
var _brush: TerrainBrush
var _dirty := false
var _saving := false  ## the reimport on its way is of our own save


## A canvas over these L8 bytes (`size` pixels of `cell_m` metres, row by row), edited in place. No editor.
static func over(bytes: PackedByteArray, size: Vector2i, cell_m: float) -> DensityCanvas:
	var canvas := DensityCanvas.new()
	canvas._work = bytes
	canvas._size = size
	canvas._cell_m = cell_m
	return canvas


## The editor's canvas of `layer`'s density picture; null when it has none (or it cannot be read).
static func of(layer: FloraLayer) -> DensityCanvas:
	if layer.density == null:
		return null
	var canvas := DensityCanvas.new()
	canvas._layer = layer
	return canvas if canvas._read() else null


## Where a new picture of `layer` goes: `<map>/flora/<node_name_in_snake>.png` beside the map's pictures (the folder of its
## Terrain's ground_roles, else heights, else the scene's), with _2, _3… when the name is taken. "" outside a saved map.
static func new_picture_path(layer: FloraLayer) -> String:
	var folder := _map_folder(layer)
	if folder.is_empty():
		return ""
	var stem := String(layer.name).to_snake_case()
	var path := folder.path_join(FOLDER).path_join(stem + ".png")
	var n := 2
	while FileAccess.file_exists(path):
		path = folder.path_join(FOLDER).path_join("%s_%d.png" % [stem, n])
		n += 1
	return path


## Writes a blank (0) picture for `layer` at `path` (square, ceili(TerrainGrid.SIZE_M / cell_m) pixels a side) with the
## fixed `.import`, and imports it now. "" or the error.
static func create_picture(layer: FloraLayer, path: String) -> String:
	var side := ceili(TerrainGrid.SIZE_M / layer.cell_m)
	var error := CanvasFiles.blank(path, Vector2i(side, side), Image.FORMAT_L8, Color.BLACK)
	if not error.is_empty():
		return error
	CanvasFiles.reimport(PackedStringArray([path]))
	print("Flora: imagen nueva ", path)
	return ""


func context() -> Node:
	return _layer


func cell_rect(center_m: Vector2, reach_m: float) -> Rect2i:
	return PaintRules.pixel_rect(center_m, reach_m, _cell_m, _size)


func begin(mode: int, brush: TerrainBrush, _at_m: Vector2) -> void:
	# The layer got another picture (the inspector, an undo): paint on that one.
	if _layer != null and _layer.density != null and _layer.density.resource_path != _path:
		_read()
	_mode = mode as Mode
	_brush = brush


func dab(at_m: Vector2, _vertical_px: float) -> Rect2i:
	var rect := cell_rect(at_m, _brush.size_m)
	if not rect.has_area():
		return rect
	var target := 0 if _mode == Mode.ERASE else roundi(_brush.density * 255.0)
	PaintRules.toward(_work, _size.x, rect, PaintRules.weights(_brush, at_m, rect, _cell_m), target, _brush.flow)
	return rect


func copy() -> Variant:
	return _work.duplicate()


func patch(rect: Rect2i, from: Variant = null) -> RefCounted:
	var source: PackedByteArray = _work if from == null else from
	return BrushCanvas.PixelPatch.read(source, _size.x, 1, rect)


func write(patches: Array) -> void:
	for each: BrushCanvas.PixelPatch in patches:
		each.write(_work, _size.x, 1)
	if _layer != null:
		_dirty = true
		preview(BrushCanvas.span(patches))


func preview(rect: Rect2i) -> void:
	if _layer == null or not is_instance_valid(_layer) or not rect.has_area():
		return
	var picture := Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_L8, _work)
	_layer.show_painting(picture, Rect2(Vector2(rect.position) * _cell_m, Vector2(rect.size) * _cell_m))


func is_dirty() -> bool:
	return _dirty


func save() -> String:
	if not _dirty:
		return ""
	var error := CanvasFiles.save_png(Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_L8, _work), _path)
	if not error.is_empty():
		return error
	_dirty = false
	_saving = true
	print("Flora: guardada ", _path)
	reimport_picture.call_deferred(_path)
	return ""


func label(mode: int) -> String:
	return LABELS[mode]


func file() -> String:
	return _path


## The PNG came back from a reimport: after our own save it already holds the working picture; an outside edit (Krita)
## replaces it unless this canvas has unsaved strokes. Either way the layer shows its imported picture again.
func reloaded() -> void:
	if _layer == null or not is_instance_valid(_layer):
		return
	if _saving or not _dirty:
		if not _saving:
			_read()
		_layer.stop_painting()
	_saving = false


## The bytes being painted (the arrays themselves: headless checks read them).
func work() -> PackedByteArray:
	return _work


## Tells the editor the picture at `path` changed and imports it again.
static func reimport_picture(path: String) -> void:
	CanvasFiles.reimport(PackedStringArray([path]))


func _read() -> bool:
	var picture := _layer.density_image()
	if picture == null:
		return false
	_path = _layer.density.resource_path
	_size = picture.get_size()
	_cell_m = _layer.cell_m
	_work = picture.get_data()
	_dirty = false
	return true


static func _map_folder(layer: FloraLayer) -> String:
	var at: Node = layer
	while at != null and not (at is MapRoot):
		at = at.get_parent()
	var terrain: Terrain = (at as MapRoot).terrain if at != null else null
	if terrain != null and terrain.ground_roles != null and not terrain.ground_roles.resource_path.is_empty():
		return terrain.ground_roles.resource_path.get_base_dir()
	if terrain != null and terrain.heights != null and not terrain.heights.resource_path.is_empty():
		return terrain.heights.resource_path.get_base_dir()
	var scene: Node = layer.owner if layer.owner != null else layer
	return scene.scene_file_path.get_base_dir()
