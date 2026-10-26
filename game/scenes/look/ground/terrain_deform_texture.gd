@tool
class_name TerrainDeformTexture
extends LookLayer

## Hands the ground shader how far the land has moved: a 256x256 texture of two floats per 10 m vertex (how high, and 1
## where a vertex was taken away) set as the global `terrain_deform_map`, uploaded once per frame and only when the
## ground changed. The mesh of the map is never rebuilt: the shader moves its vertices. The first change also turns
## `terrain_deform_on` on, so a match that never deforms the ground pays nothing. It does not decide how the ground
## moves (Terrain). Presentation only: the rig is freed in a dedicated or headless process.

const MAP := &"terrain_deform_map"
const ON := &"terrain_deform_on"

## The rig this layer belongs to (look_rig.tscn sets it): its `ground` is the one to follow.
@export var rig: LookRig

var _shape: GroundSurface
var _image: Image
var _texture: ImageTexture
var _dirty := false


func _ready() -> void:
	set_process(not Engine.is_editor_hint())


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if rig != null else PackedStringArray(["Falta el socket Rig (el LookRig del mapa)."])


func _process(_delta: float) -> void:
	if _shape == null:
		_follow(rig.ground if rig != null else null)
	elif _dirty:
		_upload()


func _follow(ground: GroundSurface) -> void:
	if ground == null or not ground.is_loaded():
		return
	_shape = ground
	_image = Image.create_empty(_shape.field().size.x, _shape.field().size.y, false, Image.FORMAT_RGF)
	_texture = ImageTexture.create_from_image(_image)
	RenderingServer.global_shader_parameter_set(MAP, _texture)
	_shape.changed.connect(_on_changed)
	# Something may have moved before this layer started (a peer that joined late).
	_dirty = _shape.field().rev > 0 or _shape.field().live_count() > 0


func _on_changed(_area: Rect2) -> void:
	_dirty = true


func _upload() -> void:
	_dirty = false
	_image.set_data(_shape.field().size.x, _shape.field().size.y, false, Image.FORMAT_RGF, _shape.field().texels.to_byte_array())
	_texture.update(_image)
	RenderingServer.global_shader_parameter_set(ON, 1.0)


func _exit_tree() -> void:
	if _shape != null and is_instance_valid(_shape) and _shape.changed.is_connected(_on_changed):
		_shape.changed.disconnect(_on_changed)
	RenderingServer.global_shader_parameter_set(ON, 0.0)
