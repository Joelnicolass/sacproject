class_name GroundScars
extends Node3D

## The marks on the ground of a map (a burn under an explosion, a crack where a rock lands): the one owner of `marks` (what was
## painted, in order) and of the tiles drawn from it. A mark is a picture painted INTO the ground, 0.15625 m per pixel, centered, never turned, over
## what is there; marks on a 10 m tile pile up and never fade; past `max_tiles` painted tiles the one painted longest ago is cleaned (ground_scars.gdshaderinc reads it).
## Presentation only: headless (dedicated) it holds nothing. ScarMark decides when; GroundScarsNet hands `marks` to a peer back from a drop.

const GROUP := &"ground_scars"
const INDEX_PARAM := &"scar_index"
const TILES_PARAM := &"scar_tiles"

## The map's ground (to know how high it is under a mark).
@export var terrain: Terrain
## The player's graphics options: «Cantidad de marcas». Empty: `max_tiles`.
@export var prefs: GraphicsPrefs
@export_range(32, 256) var max_tiles := 256
## The painted tiles the shaders read (empty in the scene; `_ready` fills it).
@export var tiles: Texture2DArray

var marks := GroundScarRecord.new()
var _pool: GroundScarRules.Pool
var _layers: Array[Image] = []
var _index: Image
var _index_texture: ImageTexture
var _images: Dictionary = {}  # texture -> Image (RGBA8), read once
## The last 40 requests to paint, accepted or refused and why (the capture harness prints them).
static var log_lines := PackedStringArray()


## The marks of the map `node` is in; null when none or headless.
static func of(node: Node) -> GroundScars:
	if node == null or not node.is_inside_tree():
		return null
	var found := node.get_tree().get_first_node_in_group(GROUP) as GroundScars
	return found if found != null and found.is_active() else null


func _ready() -> void:
	add_to_group(GROUP)
	if DisplayServer.get_name() == "headless" or tiles == null or terrain == null:
		return
	var count := GroundScarRules.clamp_capacity(prefs.scar_tiles() if prefs != null else max_tiles)
	_pool = GroundScarRules.Pool.new(count)
	for i in count:
		_layers.append(Image.create_empty(GroundScarRules.TILE_TEXELS, GroundScarRules.TILE_TEXELS, false, Image.FORMAT_RGBA8))
	var grid := GroundScarRules.grid_for(terrain.bounds())  # one index texel per 10 m tile of the map
	_index = Image.create_empty(grid.x, grid.y, false, Image.FORMAT_RGBA8)
	tiles.create_from_images(_layers)
	_index_texture = ImageTexture.create_from_image(_index)
	_publish()


## Reparenting leaves and enters the tree without a new `_ready`: the shaders get the textures again.
func _enter_tree() -> void:
	if _pool != null:
		_publish()


func _exit_tree() -> void:
	if _pool != null and is_queued_for_deletion():
		RenderingServer.global_shader_parameter_set(INDEX_PARAM, RID())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if terrain == null:
		warnings.append("Asigná `terrain` (el Terrain del mapa).")
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
	var ground_y := terrain.height_at(local.x, local.z)
	var refusal := GroundScarRules.refusal(terrain.is_on_ground(local.x, local.z), ground_y, local.y, max_height_m)
	if not refusal.is_empty():
		note("refused (%s) %s at map %s, max height %.1f" % [refusal, texture.resource_path.get_file(), local, max_height_m])
		return false
	var mark := _image_of(texture)
	var origin := GroundScarRules.texel_origin(Vector2(local.x, local.z), mark.get_size())
	var touched := GroundScarRules.tiles_touched(origin, mark.get_size(), GroundScarRules.grid_for(terrain.bounds()))
	for tile in touched:
		_paint_tile(mark, origin, tile)
	_index_texture.update(_index)
	_publish()
	note("painted %s at map %s, %.1f m over the ground, %d tiles" % [texture.resource_path.get_file(), local, local.y - ground_y, touched.size()])
	if not touched.is_empty():
		marks.add(texture, at, max_height_m)
	return not touched.is_empty()


## Cleans every tile and forgets the marks (before painting the list of another peer again).
func clear() -> void:
	if _pool != null:
		_pool = GroundScarRules.Pool.new(_pool.capacity)
		_index.fill(Color(0.0, 0.0, 0.0, 0.0))
		_index_texture.update(_index)
	marks.clear()


static func note(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 40:
		log_lines.remove_at(0)


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
		_images[texture] = texture.get_image()
		(_images[texture] as Image).convert(Image.FORMAT_RGBA8)
	return _images[texture]


func _publish() -> void:
	RenderingServer.global_shader_parameter_set(INDEX_PARAM, _index_texture.get_rid())
	RenderingServer.global_shader_parameter_set(TILES_PARAM, tiles.get_rid())
