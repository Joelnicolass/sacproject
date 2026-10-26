@tool
class_name TerrainDeformTexture
extends LookLayer

## Hands the ground shader how far the land has moved, two floats per 10 m vertex (how high, and 1 where a vertex was taken
## away), in two textures: the whole map (`terrain_deform_map`, 256x256), sent again only when what stays or the holes
## change, and a small one (`terrain_live_map`) over the rect `terrain_live_rect` where stamps are playing, sent every frame
## they move. Inside that rect the shader reads the small one. The mesh of the map is never rebuilt: the shader moves its
## vertices. The first change also turns `terrain_deform_on` on, so a match that never deforms the ground pays nothing. It
## does not decide how the ground moves (Terrain). Presentation only: the rig is freed in a dedicated or headless process.

const MAP := &"terrain_deform_map"
const LIVE_MAP := &"terrain_live_map"
const LIVE_RECT := &"terrain_live_rect"
const ON := &"terrain_deform_on"
const BYTES_PER_VERTEX := 8

## The rig this layer belongs to (look_rig.tscn sets it): its `ground` is the one to follow.
@export var rig: LookRig

## What the last frame sent to the GPU and the CPU time it took (debug/perf/terrain_deform_bench prints them).
var uploaded_bytes := 0
var upload_usec := 0

var _shape: Terrain
var _map_image: Image
var _map: ImageTexture
var _live_image: Image
var _strip := Image.create_empty(1, 1, false, Image.FORMAT_RGF)  ## the whole rows the live rect spans
var _live: ImageTexture
## The vertices the small texture covers: every stamp that played since none was playing. Empty = none plays.
var _live_rect := Rect2i()
## (rev, holes version) of the field at the last change seen: a change that moves it is one of what stays.
var _settled := Vector2i(-1, -1)
var _map_dirty := false
var _live_dirty := false
## The map was sent while a stamp was playing, so it holds that shift: it goes again when the last stamp is over.
var _map_has_live := false
var _shown_rect := Rect2i()
var _on := false


func _ready() -> void:
	set_process(not Engine.is_editor_hint())


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if rig != null else PackedStringArray(["Falta el socket Rig (el LookRig del mapa)."])


func _process(_delta: float) -> void:
	uploaded_bytes = 0
	upload_usec = 0
	if _shape == null:
		_follow(rig.terrain if rig != null else null)
	elif _map_dirty or _live_dirty:
		var started := Time.get_ticks_usec()
		_upload()
		upload_usec = Time.get_ticks_usec() - started


func _follow(ground: Terrain) -> void:
	if ground == null or not ground.is_loaded():
		return
	_shape = ground
	var field := _shape.field()
	_map_image = Image.create_empty(field.size.x, field.size.y, false, Image.FORMAT_RGF)
	_map = ImageTexture.create_from_image(_map_image)
	_live_image = Image.create_empty(1, 1, false, Image.FORMAT_RGF)
	_live = ImageTexture.create_from_image(_live_image)
	RenderingServer.global_shader_parameter_set(MAP, _map)
	RenderingServer.global_shader_parameter_set(LIVE_MAP, _live)
	RenderingServer.global_shader_parameter_set(LIVE_RECT, Vector4.ZERO)
	_settled = _settled_of(field)
	_shape.changed.connect(_on_changed)
	# Something may have moved before this layer started (a peer that joined late).
	_map_dirty = field.rev > 0 or field.live_count() > 0


func _on_changed(area: Rect2) -> void:
	var field := _shape.field()
	var settled := _settled_of(field)
	_live_dirty = _live_dirty or _live_rect.has_area()
	if settled != _settled:
		_settled = settled
		_map_dirty = true
	elif field.live_count() > 0:
		var rect := Rect2i(Vector2i((area.position / field.cell_m).round()), Vector2i((area.size / field.cell_m).round()))
		_live_rect = _live_rect.merge(rect) if _live_rect.has_area() else rect
		_live_dirty = true


func _upload() -> void:
	var field := _shape.field()
	if field.live_count() == 0 and _live_rect.has_area():
		_live_rect = Rect2i()
		_live_dirty = true
		_map_dirty = _map_dirty or _map_has_live
	if _map_dirty:
		_map_dirty = false
		_map_has_live = field.live_count() > 0
		var bytes := field.texels.to_byte_array()
		_map_image.set_data(field.size.x, field.size.y, false, Image.FORMAT_RGF, bytes)
		RenderingServer.texture_2d_update(_map.get_rid(), _map_image, 0)
		uploaded_bytes += bytes.size()
	if _live_dirty:
		_live_dirty = false
		_upload_live(field)
	if not _on:
		_on = true
		RenderingServer.global_shader_parameter_set(ON, 1.0)


## Copies `_live_rect` out of the field into the small texture (or empties the rect when no stamp plays). The whole rows it
## spans go over in one slice and the rect is cut out natively: a slice per row costs three times as much in GDScript.
func _upload_live(field: GroundField) -> void:
	var rect := _live_rect
	if rect.has_area():
		var first := rect.position.y * field.size.x * 2
		var rows := field.texels.slice(first, first + rect.size.y * field.size.x * 2).to_byte_array()
		_strip.set_data(field.size.x, rect.size.y, false, Image.FORMAT_RGF, rows)
		var resized := _live_image.get_size() != rect.size
		if resized:
			_live_image = Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGF)
		_live_image.blit_rect(_strip, Rect2i(rect.position.x, 0, rect.size.x, rect.size.y), Vector2i.ZERO)
		if resized:
			_live.set_image(_live_image)
		else:
			RenderingServer.texture_2d_update(_live.get_rid(), _live_image, 0)
		uploaded_bytes += rect.get_area() * BYTES_PER_VERTEX
	if rect != _shown_rect:
		_shown_rect = rect
		RenderingServer.global_shader_parameter_set(LIVE_RECT, Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


static func _settled_of(field: GroundField) -> Vector2i:
	return Vector2i(field.rev, field.holes.version)


func _exit_tree() -> void:
	if _shape != null and is_instance_valid(_shape) and _shape.changed.is_connected(_on_changed):
		_shape.changed.disconnect(_on_changed)
	RenderingServer.global_shader_parameter_set(ON, 0.0)
	RenderingServer.global_shader_parameter_set(LIVE_RECT, Vector4.ZERO)
	_on = false
	_shown_rect = Rect2i()
