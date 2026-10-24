class_name GroundScars
extends Node3D

## The marks on the ground of a map (a burn under an explosion, a crack where a rock lands): the one owner of the painted
## tiles. A mark is a small picture painted INTO the ground, 0.15625 m per pixel, centered where it lands and never turned,
## over what is there; marks on the same 10 m tile pile up, they never fade, and when the map holds `max_tiles` painted tiles
## the tile that was painted longest ago is cleaned. The ground shaders read the result (ground_scars.gdshaderinc).
## Presentation only: with no window (headless, dedicated server) it holds nothing and `stamp` does nothing. It does not
## decide when a mark happens (ScarMark does) and never touches the ground's mesh, collision or height.
## Ref: rfcs/research/061S-scar-ground-marks.md.

## ScarMark finds the marks of its map through this group.
const GROUP := &"ground_scars"
## The shader globals ground_scars.gdshaderinc reads (declared in project.godot).
const INDEX_PARAM := &"scar_index"
const TILES_PARAM := &"scar_tiles"

## The map's ground (to know how high it is under a mark).
@export var shape: TerrainShape
## The player's graphics options: «Cantidad de marcas». Empty: `max_tiles`.
@export var prefs: GraphicsPrefs
@export_range(32, 256) var max_tiles := 256
## The array of painted tiles the ground shaders read (empty in the scene; `_ready` fills it with the layers).
@export var tiles: Texture2DArray

var _pool: GroundScarRules.Pool
var _layers: Array[Image] = []
var _index: Image
var _index_texture: ImageTexture
## texture -> Image (RGBA8), read once.
var _images: Dictionary = {}
static var _blank: ImageTexture


## The marks of the map `node` is in; null when it has none or draws nothing (headless).
static func of(node: Node) -> GroundScars:
	if node == null or not node.is_inside_tree():
		return null
	var found := node.get_tree().get_first_node_in_group(GROUP) as GroundScars
	return found if found != null and found.is_active() else null


func _ready() -> void:
	add_to_group(GROUP)
	if DisplayServer.get_name() == "headless" or tiles == null:
		return
	var count := GroundScarRules.clamp_capacity(prefs.scar_tiles() if prefs != null else max_tiles)
	_pool = GroundScarRules.Pool.new(count)
	for i in count:
		_layers.append(Image.create_empty(GroundScarRules.TILE_TEXELS, GroundScarRules.TILE_TEXELS, false, Image.FORMAT_RGBA8))
	_index = Image.create_empty(GroundScarRules.GRID, GroundScarRules.GRID, false, Image.FORMAT_RGBA8)
	tiles.create_from_images(_layers)
	_index_texture = ImageTexture.create_from_image(_index)
	_publish(_index_texture, tiles)


func _exit_tree() -> void:
	if _pool == null:
		return
	if _blank == null:
		_blank = ImageTexture.create_from_image(Image.create_empty(GroundScarRules.GRID, GroundScarRules.GRID, false, Image.FORMAT_RGBA8))
	RenderingServer.global_shader_parameter_set(INDEX_PARAM, _blank)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if shape == null:
		warnings.append("Asigná `shape` (el TerrainShape del mapa).")
	if prefs == null:
		warnings.append(GraphicsPrefs.socket_warning(prefs))
	if tiles == null:
		warnings.append("Asigná `tiles` (un Texture2DArray vacío).")
	return warnings


func is_active() -> bool:
	return _pool != null


## How many tiles the map can hold at once (the option; 0 when nothing is drawn).
func capacity() -> int:
	return _pool.capacity if _pool != null else 0


## How many tiles hold a mark now.
func painted_tiles() -> int:
	return _pool.size() if _pool != null else 0


## Paints `texture` centered at the world point `at`. `max_height_m`: not drawn when the ground under it is that far from
## the point (0 = always). False when nothing was painted.
func stamp(texture: Texture2D, at: Vector3, max_height_m := 0.0) -> bool:
	if _pool == null or texture == null:
		return false
	var local := to_local(at)
	if not _near_ground(local, max_height_m):
		return false
	var mark := _image_of(texture)
	var origin := GroundScarRules.texel_origin(Vector2(local.x, local.z), mark.get_size())
	var touched := GroundScarRules.tiles_touched(origin, mark.get_size())
	for tile in touched:
		_paint_tile(mark, origin, tile)
	_index_texture.update(_index)
	return not touched.is_empty()


func _near_ground(local: Vector3, max_height_m: float) -> bool:
	if shape == null or not shape.is_on_ground(local.x, local.z):
		return false
	return GroundScarRules.allows_height(shape.height_at(local.x, local.z), local.y, max_height_m)


func _paint_tile(mark: Image, origin: Vector2i, tile: Vector2i) -> void:
	var layer := _pool.claim(tile)
	if _pool.evicted != GroundScarRules.NO_TILE:
		_index.set_pixelv(_pool.evicted, Color(0.0, 0.0, 0.0, 0.0))
	var image := _layers[layer]
	if _pool.fresh:
		image.fill(Color(0.0, 0.0, 0.0, 0.0))
		_index.set_pixelv(tile, GroundScarRules.index_color(layer))
	GroundScarRules.paint(image, mark, origin, tile)
	tiles.update_layer(image, layer)


func _image_of(texture: Texture2D) -> Image:
	if not _images.has(texture):
		var image := texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		_images[texture] = image
	return _images[texture]


func _publish(index: Texture2D, array: Texture2DArray) -> void:
	RenderingServer.global_shader_parameter_set(INDEX_PARAM, index)
	RenderingServer.global_shader_parameter_set(TILES_PARAM, array)
