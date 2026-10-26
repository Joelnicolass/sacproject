class_name GroundTiles
extends RefCounted

## What is known per 10 m cell of a map (256x256 row-major): the original tile id (read once from the map's tiles image, again
## only when the image is another) and how many land triangles the cell has. What it does NOT do: say anything about heights or
## holes (that is Terrain, its owner).

var _ids := PackedByteArray()
var _source: Image


## The ids of `tiles` (the map's tiles.png imported as Image, the id in R); empty without one.
func ids(tiles: Image) -> PackedByteArray:
	if tiles != _source:
		_source = tiles
		_ids = _load(tiles)
	return _ids


## Land triangles per cell from the index `cells` (two ids per cell, -1 for none).
static func counts(cells: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(TerrainGrid.COUNT)
	if cells.size() == TerrainGrid.COUNT * 2:
		for cell in out.size():
			out[cell] = int(cells[cell * 2] >= 0) + int(cells[cell * 2 + 1] >= 0)
	return out


static func _load(image: Image) -> PackedByteArray:
	# importer="image": exact pixels, no sRGB, no mipmaps, no compression
	if image == null:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(TerrainGrid.COUNT)
	for y in TerrainGrid.SIDE:
		for x in TerrainGrid.SIDE:
			out[TerrainGrid.id_of(Vector2i(x, y))] = int(image.get_pixel(x, y).r8)
	return out
