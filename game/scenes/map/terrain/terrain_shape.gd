@tool
class_name TerrainShape
extends Node

## The one owner of the map's ground as numbers: the raw triangles (`data`), the tile of each 10 m cell, and what is
## derived from them (land height, holes, how many triangles each cell has, the lowest land). Everyone who needs a
## height or to know if a point is land asks here; the mesh (Terrain) and a physics ray (GroundRay) are other things.
## It is a child `Shape` of Terrain. A map that is not loaded answers like a map with only holes. The ground can move
## after loading (TerrainDeformer writes `displacement()`): every answer here already includes it.
## `changed(rect)` says which part of the map (x, z in metres) moved, for whoever draws or collides it.

signal changed(rect: Rect2)

const GROUP := &"terrain_shape"

## The map's raw ground (assets/original/maps/<map>/terrain.res). The map scene assigns it. Only the editor falls back
## to the active map's, with a warning; in a match a missing `data` is an error, not a silent default.
@export var data: MapTerrainData:
	set(value):
		data = value
		_reindex()
## The map's tile index (256x256, tile id in R). Imported as Image, read on the CPU. Empty = the active map's
## (MapDefinition.tiles), which may have none.
@export_file("*.png") var tiles_path := "":
	set(value):
		tiles_path = value
		_tiles = PackedByteArray()
		_tiles_read = false

var _index := TerrainRules.Index.new()
var _displacement := TerrainDisplacement.new()
var _counts := PackedByteArray()
var _tiles := PackedByteArray()
var _tiles_read := false


## A shape that holds `data` (and its tiles), for a probe or a tool that builds a ground without a map scene.
static func with_data(ground: MapTerrainData, tiles := "") -> TerrainShape:
	var built := TerrainShape.new()
	built.tiles_path = tiles
	built.data = ground
	return built


## The shape of the map the `node` is in; null when it is not in the tree or no ground is loaded.
static func of(node: Node) -> TerrainShape:
	if node == null or not node.is_inside_tree():
		return null
	var shape := node.get_tree().get_first_node_in_group(GROUP) as TerrainShape
	return shape if shape != null and shape.is_loaded() else null


func _ready() -> void:
	add_to_group(GROUP)
	if data == null and Engine.is_editor_hint():
		_use_active_map_data()


## True once there is land to ask about.
func is_loaded() -> bool:
	return not _index.ground.is_empty()


## Land height under (x, z) in world units, NAN over a hole.
func height_at(x: float, z: float) -> float:
	return TerrainRules.height_in(x, z, _index.ground, _index.cells, _displacement.texels, _index.corners)


## True when a land triangle lies under (x, z). Holes and the map rim have none.
func is_on_ground(x: float, z: float) -> bool:
	return TerrainRules.triangle_in(x, z, _index.ground, _index.cells, _displacement.texels, _index.corners) >= 0


## The lowest land vertex (0 without land).
func lowest() -> float:
	return _index.lowest


## A Callable(x, z) -> float that answers like height_at from a copy of the index and the displacement taken now (a later
## change does not touch it). It reads no node, so a WorkerThreadPool task may call it.
func sampler() -> Callable:
	return TerrainRules.height_in.bind(_index.ground, _index.cells, _displacement.snapshot(), _index.corners)


## How far the ground has moved from the file. Only TerrainDeformer writes it.
func displacement() -> TerrainDisplacement:
	return _displacement


## Tells whoever listens that the vertices of `vertices` (grid coordinates) moved.
func notify_changed(vertices: Rect2i) -> void:
	changed.emit(Rect2(Vector2(vertices.position) * TerrainRules.CELL, Vector2(vertices.size) * TerrainRules.CELL))


## How many land triangles each 10 m cell has: 0 a hole or the rim, 1 half a cell, 2 a full one. 256x256 row-major
## (z * 256 + x).
func cell_counts() -> PackedByteArray:
	if _counts.size() != TerrainRules.GRID * TerrainRules.GRID:
		_counts = PackedByteArray()
		_counts.resize(TerrainRules.GRID * TerrainRules.GRID)
		var has_cells := _index.cells.size() == TerrainRules.GRID * TerrainRules.GRID * 2
		for cell in _counts.size():
			var count := 0
			if has_cells:
				count = int(_index.cells[cell * 2] >= 0) + int(_index.cells[cell * 2 + 1] >= 0)
			_counts[cell] = count
	return _counts


## The original tile id of each 10 m cell, 256x256 row-major (empty without the map's tiles.png).
func tile_ids() -> PackedByteArray:
	if not _tiles_read:
		_tiles_read = true
		_tiles = _read_tiles()
	return _tiles


## Replaces the tile index (256x256, one id per 10 m cell): for a ground that is not made from a map's tiles.png,
## like the grass laboratory's patch.
func use_tiles(ids: PackedByteArray) -> void:
	_tiles = ids
	_tiles_read = true


func _reindex() -> void:
	_index = TerrainRules.index(data) if data != null and data.is_valid() else TerrainRules.Index.new()
	_displacement = TerrainDisplacement.new()
	_counts = PackedByteArray()


func _use_active_map_data() -> void:
	var fallback := MapCatalog.active().terrain
	if fallback == null:
		return
	push_warning("TerrainShape.data is empty: the editor shows the ground of '%s'. Assign data in the scene." % MapCatalog.active().tag)
	data = fallback


func _read_tiles() -> PackedByteArray:
	# importer="image": exact pixels, no sRGB, no mipmaps, no compression
	var image := load(tiles_path) as Image if not tiles_path.is_empty() and ResourceLoader.exists(tiles_path) else MapCatalog.active().tiles
	if image == null:
		return PackedByteArray()
	var ids := PackedByteArray()
	ids.resize(TerrainRules.GRID * TerrainRules.GRID)
	for y in TerrainRules.GRID:
		for x in TerrainRules.GRID:
			ids[y * TerrainRules.GRID + x] = int(image.get_pixel(x, y).r8)
	return ids
