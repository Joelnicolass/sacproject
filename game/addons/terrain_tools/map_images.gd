@tool
extends RefCounted

## The two pictures a map's ground is kept in, read into a TerrainHeights and written back from one:
##  - `heights.png`: grey, 16 bits, one pixel per lattice vertex (256 x 256, row by row as TerrainGrid); the value times
##    `metres_per_unit` (0.1 m by default) is the height above the map's lowest land;
##  - `void.png`, beside it: white = void, the height under it is kept in heights.png. Any PNG an image editor saves
##    (1 or 8 bits, grey or colour) is read through Godot's Image. Missing = no void.
## Not: the PNG bytes of heights.png (Png16), importing (TerrainHeightsImporter), what the ground does with them (Terrain).

const Png16 := preload("res://addons/terrain_tools/png16.gd")
const HEIGHTS_FILE := "heights.png"
const VOID_FILE := "void.png"
const DEFAULT_METRES_PER_UNIT := 0.1
const TOP_UNIT := 65535
const VOID_GREY := 128  ## a void.png pixel this bright or brighter is void


## What read or write did. `error` is empty when it worked; `heights` is set by read; `written` lists the files write
## changed (an unchanged file is not written again).
class Result:
	var heights: TerrainHeights
	var written := PackedStringArray()
	var error := ""


## The TerrainHeights of a heights.png and of the void.png in its folder.
static func read(heights_path: String, metres_per_unit: float = DEFAULT_METRES_PER_UNIT) -> Result:
	var result := Result.new()
	if not (metres_per_unit > 0.0):
		return _failed(result, "metres_per_unit must be above 0 (it is %s)." % metres_per_unit)
	var picture := Png16.read_file(heights_path)
	if not picture.error.is_empty():
		return _failed(result, "%s: %s." % [heights_path, picture.error])
	var refused := _size_refused(heights_path, picture.width, picture.height)
	if not refused.is_empty():
		return _failed(result, refused)
	var heights_m := PackedFloat32Array()
	heights_m.resize(TerrainHeights.COUNT)
	for v in TerrainHeights.COUNT:
		heights_m[v] = picture.samples[v] * metres_per_unit
	var void_mask := PackedByteArray()
	void_mask.resize(TerrainHeights.COUNT)  # new bytes are 0: land
	var void_path := heights_path.get_base_dir().path_join(VOID_FILE)
	if FileAccess.file_exists(void_path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(void_path)) != OK:
			return _failed(result, "%s is not a PNG Godot can read." % void_path)
		refused = _size_refused(void_path, image.get_width(), image.get_height())
		if not refused.is_empty():
			return _failed(result, refused)
		image.convert(Image.FORMAT_L8)
		var grey := image.get_data()
		for v in TerrainHeights.COUNT:
			void_mask[v] = 1 if grey[v] >= VOID_GREY else 0
	result.heights = TerrainHeights.new()
	result.heights.heights_m = heights_m
	result.heights.void_mask = void_mask
	return result


## Writes `heights` as heights.png and void.png in `folder` (void.png only when there is a void; a stale one goes).
## Heights are rounded to whole units, below 0 kept at 0 and above TOP_UNIT units at the top (see units).
static func write(heights: TerrainHeights, folder: String, metres_per_unit: float = DEFAULT_METRES_PER_UNIT) -> Result:
	var result := Result.new()
	if heights == null or not heights.is_valid() or not (metres_per_unit > 0.0):
		return _failed(result, "nothing to write to %s (no valid TerrainHeights, or metres_per_unit is not above 0)." % folder)
	var side := TerrainGrid.SIDE
	_store(result, folder.path_join(HEIGHTS_FILE), Png16.encode(side, side, units(heights, metres_per_unit), 16))
	var void_path := folder.path_join(VOID_FILE)
	if heights.void_mask.has(1):
		var grey := PackedInt32Array()
		grey.resize(TerrainHeights.COUNT)
		for v in TerrainHeights.COUNT:
			grey[v] = 255 if heights.is_void(v) else 0
		_store(result, void_path, Png16.encode(side, side, grey, 8))
	elif FileAccess.file_exists(void_path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(void_path)) != OK:
			result.error = "could not delete the stale %s." % void_path
		else:
			result.written.append(void_path)
	return result


## The heights.png value of every vertex: the height in whole `metres_per_unit`, clamped to 0 .. TOP_UNIT.
static func units(heights: TerrainHeights, metres_per_unit: float = DEFAULT_METRES_PER_UNIT) -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(TerrainHeights.COUNT)
	for v in TerrainHeights.COUNT:
		values[v] = clampi(roundi(heights.height(v) / metres_per_unit), 0, TOP_UNIT)
	return values


static func _store(result: Result, path: String, bytes: PackedByteArray) -> void:
	if not result.error.is_empty():
		return
	if bytes.is_empty():
		result.error = "could not encode %s." % path
		return
	if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == bytes:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result.error = "could not write %s (error %d)." % [path, FileAccess.get_open_error()]
		return
	file.store_buffer(bytes)
	file.close()
	result.written.append(path)


static func _size_refused(path: String, width: int, height: int) -> String:
	if width == TerrainGrid.SIDE and height == TerrainGrid.SIDE:
		return ""
	return "%s is %d x %d pixels; a map's ground is %d x %d (one pixel per lattice vertex, 10 m apart)." % [
			path, width, height, TerrainGrid.SIDE, TerrainGrid.SIDE]


static func _failed(result: Result, message: String) -> Result:
	result.heights = null
	result.error = message
	return result
