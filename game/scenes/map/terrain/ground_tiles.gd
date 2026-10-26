class_name GroundTiles
extends RefCounted

## What is known per 10 m cell of a map (256x256 row-major): the original tile id (empty without the map's tiles.png, read
## once when first asked) and how many land triangles the cell has. What it does NOT do: say anything about heights or
## holes (that is GroundSurface, its owner).

var _ids := PackedByteArray()
var _read := false
var _counts := PackedByteArray()


## Forgets what was read (the tiles file changed).
func reset() -> void:
	_ids = PackedByteArray()
	_read = false


## The ids of the PNG at `path` (empty path or no file = the active map's tiles.png).
func ids(path: String) -> PackedByteArray:
	if not _read:
		_read = true
		_ids = _load(path)
	return _ids


## Land triangles per cell from the index `cells` (two ids per cell, -1 for none); made once, until `forget_counts`.
func counts(cells: PackedInt32Array) -> PackedByteArray:
	if _counts.size() != TerrainGrid.COUNT:
		_counts.resize(TerrainGrid.COUNT)
		_counts.fill(0)
		if cells.size() == TerrainGrid.COUNT * 2:
			for cell in _counts.size():
				_counts[cell] = int(cells[cell * 2] >= 0) + int(cells[cell * 2 + 1] >= 0)
	return _counts


## The index changed: the counts must be made again.
func forget_counts() -> void:
	_counts = PackedByteArray()


## Replaces the ids (256x256, one per 10 m cell): for a ground that is not made from a map's tiles.png.
func use(replacement: PackedByteArray) -> void:
	_ids = replacement
	_read = true


func _load(path: String) -> PackedByteArray:
	# importer="image": exact pixels, no sRGB, no mipmaps, no compression
	var image := load(path) as Image if not path.is_empty() and ResourceLoader.exists(path) else MapCatalog.active().tiles
	if image == null:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(TerrainGrid.COUNT)
	for y in TerrainGrid.SIDE:
		for x in TerrainGrid.SIDE:
			out[TerrainGrid.id_of(Vector2i(x, y))] = int(image.get_pixel(x, y).r8)
	return out
