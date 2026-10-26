@tool
class_name GroundSurface
extends Node

## The one owner of the map's ground as numbers: land height, slope, holes, the lowest land, the map's size. Everyone who needs
## a height or to know if a point is land asks here (the mesh and the physics ray GroundRay are other things). The ground is a
## grid map (`data`, the 10 m lattice) or a free mesh (`mesh_data`, any shape from Blender): `_reindex` picks the backend once
## and every answer is forwarded to it. An unloaded map answers like a map with only holes. The ground can move after loading
## (TerrainDeformer writes `field()`): `changed(rect)` says which part (x, z in metres) moved, `holes_changed(rect)` when vertices went.

signal changed(rect: Rect2)
signal holes_changed(rect: Rect2)
const GROUP := &"ground_surface"

## A grid map's raw ground (terrain.res). Only the editor falls back to the active map's, with a warning.
@export var data: MapTerrainData:
	set(value):
		data = value
		_reindex()
## A mesh map's ground (ground.res, written by the import of its glb). Set = the mesh backend answers and `data` stays empty.
@export var mesh_data: MeshGroundData:
	set(value):
		mesh_data = value
		_reindex()
## The map's tile index (256x256, tile id in R). Empty = the active map's (MapDefinition.tiles), which may have none.
@export_file("*.png") var tiles_path := "":
	set(value):
		tiles_path = value
		_tiles.reset()
## The nodes that draw this ground (the look layer dresses them, the minimap bakes them): a grid map's Terrain adds itself.
@export var meshes: Array[GeometryInstance3D] = []

## The land triangles of a grid map (read only: the walls of the holes and the falling piece read them). Empty on a mesh map.
var index := TerrainRules.Index.new()
var _field := GroundField.new()
var _tiles := GroundTiles.new()
var _ground: GroundBackend = GridGround.new(index, _field)


## A surface that holds `data` (and its tiles), for a probe or a tool that builds a ground without a map scene.
static func with_data(ground: MapTerrainData, tiles := "") -> GroundSurface:
	var built := GroundSurface.new()
	built.tiles_path = tiles
	built.data = ground
	return built


## The surface of the map the `node` is in; null when it is not in the tree or no ground is loaded.
static func of(node: Node) -> GroundSurface:
	var surface := node.get_tree().get_first_node_in_group(GROUP) as GroundSurface if node != null and node.is_inside_tree() else null
	return surface if surface != null and surface.is_loaded() else null


func _ready() -> void:
	add_to_group(GROUP)
	if data == null and mesh_data == null and Engine.is_editor_hint():
		_use_active_map_data()


## True once there is land to ask about.
func is_loaded() -> bool:
	return _ground.is_loaded()


## Land height under (x, z) in world units, NAN over a hole.
func height_at(x: float, z: float) -> float:
	return _ground.height_at(x, z)


## True when a land triangle lies under (x, z). Holes and the map rim have none.
func is_on_ground(x: float, z: float) -> bool:
	return _ground.is_on_ground(x, z)


## Unit normal (pointing up) of the land under (x, z); straight up over a hole or off the land.
func normal_at(x: float, z: float) -> Vector3:
	return _ground.normal_at(x, z)


## The map's footprint on the ground (x, z in metres; the map lives at x, z >= 0).
func bounds() -> Rect2:
	return _ground.bounds()


## The first node that draws the ground (the Terrain of a grid map); null when none was listed.
func main_mesh() -> MeshInstance3D:
	return meshes[0] as MeshInstance3D if not meshes.is_empty() and is_instance_valid(meshes[0]) else null


## Where the map is placed in the world: the transform of its first mesh (identity without one).
func map_transform() -> Transform3D:
	var mesh := main_mesh()
	return Transform3D.IDENTITY if mesh == null else (mesh.global_transform if mesh.is_inside_tree() else mesh.transform)


## Count of times the ground moved (live stamps included): whoever caches what it plants compares it.
func version() -> int:
	return _field.version


## The lowest land vertex (0 without land).
func lowest() -> float:
	return _ground.lowest()


## A Callable(x, z) -> float that answers like height_at from a copy of the ground taken now; it reads no node (WorkerThreadPool-safe).
func sampler() -> Callable:
	return _ground.sampler()


## How far the ground has moved from the file. Only TerrainDeformer writes it.
func field() -> GroundField:
	return _field


## Tells whoever listens that the vertices of `vertices` (lattice coordinates) moved.
func notify_changed(vertices: Rect2i) -> void:
	changed.emit(Rect2(Vector2(vertices.position) * _field.cell_m, Vector2(vertices.size) * _field.cell_m))


## Land triangles per 10 m cell (0 a hole or the rim, 1 half a cell, 2 a full one), 256x256 row-major (z * 256 + x).
func cell_counts() -> PackedByteArray:
	return _tiles.counts(index.cells)


## The original tile id of each 10 m cell, 256x256 row-major (empty without the map's tiles.png).
func tile_ids() -> PackedByteArray:
	return _tiles.ids(tiles_path)


## Replaces the tile index (256x256, one id per 10 m cell), for a ground not made from a map's tiles.png.
func use_tiles(ids: PackedByteArray) -> void:
	_tiles.use(ids)


## The one place that picks the backend: a mesh ground when `mesh_data` is set, the grid otherwise.
func _reindex() -> void:
	_field = GroundField.new()
	_tiles.forget_counts()
	var is_mesh := mesh_data != null and mesh_data.is_valid()
	var grid := GridGround.new(TerrainRules.index(data) if not is_mesh and data != null and data.is_valid() else TerrainRules.Index.new(), _field)
	index = grid.index
	_ground = MeshGround.new(mesh_data) if is_mesh else grid


func _use_active_map_data() -> void:
	var fallback := MapCatalog.active().terrain
	if fallback != null:
		push_warning("GroundSurface.data is empty: the editor shows the ground of '%s'. Assign data in the scene." % MapCatalog.active().tag)
		data = fallback
