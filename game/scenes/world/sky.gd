@tool
extends Node3D

const SCALING := 10240.0
const SKY_Z := 0.25
const UNDER_Z := -0.25
const CLOUD_REL := 0.7
const SEGMENTS := 64
const TEXTURE_REPEATS := 8

@export var rotation_period_s := 512.0
@export var cloud_period_s := 64.0
@export var energy := 1.7
@export var cloud_alpha := 1.0
## Smaller radius for editor visibility. Runtime still uses SCALING.
@export var editor_preview_scale := 1024.0
## World height of the sky origin.
@export var base_height := -511.0
@export var background_color := Color(1.0, 0.706, 0.471)
@export_file("*.png") var top_path := "res://cache/look/persephone/skyt.png"
@export_file("*.png") var bottom_path := "res://cache/look/persephone/skyb.png"
@export_file("*.png") var clouds_path := "res://cache/look/persephone/sky.png"

@onready var _spin: Node3D = %Spin
@onready var _top: MeshInstance3D = %Top
@onready var _bottom: MeshInstance3D = %Bottom
@onready var _clouds: MeshInstance3D = %Clouds

var _time := 0.0


## The sky places itself every frame (origin in the editor, over the camera in a match), so its
## transform is not stored: a saved scene would carry the editor preview offset of the map.
func _validate_property(property: Dictionary) -> void:
	if property.name == "transform":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func _ready() -> void:
	set_process(true)
	_rebuild_meshes()
	_bind_all()
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


func _rebuild_meshes() -> void:
	var scale_value := SCALING if not Engine.is_editor_hint() else maxf(editor_preview_scale, 64.0)
	var radius := scale_value * 0.5
	_top.mesh = _band_mesh(radius, 0.0, radius, SKY_Z * scale_value, 1.0, 0.0)
	_bottom.mesh = _band_mesh(radius * 0.8, UNDER_Z * scale_value, radius, 0.0, 0.0, 1.0)
	_clouds.mesh = _cloud_mesh(SKY_Z * CLOUD_REL * scale_value)


func _bind_all() -> void:
	_bind(_top, "band", top_path)
	_bind(_bottom, "band", bottom_path)
	_bind(_clouds, "clouds", clouds_path)
	(_clouds.material_override as ShaderMaterial).set_shader_parameter("max_alpha", cloud_alpha)


func set_textures(top: String, bottom: String, clouds: String) -> void:
	top_path = top
	bottom_path = bottom
	clouds_path = clouds
	if not is_node_ready():
		return
	_bind_all()


func current_angle() -> float:
	return fposmod(TAU * _time / rotation_period_s, TAU)


func cloud_offset() -> Vector2:
	return fposmod(_time / cloud_period_s, 1.0) * Vector2(1.0, -1.0)


func _update() -> void:
	_spin.rotation.y = -current_angle()
	(_clouds.material_override as ShaderMaterial).set_shader_parameter("offset", cloud_offset())
	if Engine.is_editor_hint():
		global_position = Vector3.ZERO
		return
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = Vector3(camera.global_position.x, base_height, camera.global_position.z)


func _bind(mesh: MeshInstance3D, uniform: String, path: String) -> void:
	var material := mesh.material_override as ShaderMaterial
	if material == null:
		mesh.material_override = ShaderMaterial.new()
		material = mesh.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("energy", energy)
	var texture := _load_png(path)
	mesh.visible = texture != null
	material.set_shader_parameter(uniform, texture)


func _load_png(path: String) -> ImageTexture:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var ext := path.get_extension().to_lower()
	var ok := ERR_FILE_UNRECOGNIZED
	match ext:
		"png":
			ok = image.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			ok = image.load_jpg_from_buffer(bytes)
		"webp":
			ok = image.load_webp_from_buffer(bytes)
		_:
			ok = image.load(path)
	if ok != OK:
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _mirror(u: float) -> float:
	return 1.0 - absf(fposmod(u, 2.0) - 1.0)


func _band_mesh(low_radius: float, low_height: float, high_radius: float, high_height: float, low_v: float, high_v: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in SEGMENTS + 1:
		var angle := TAU * i / SEGMENTS
		var around := Vector3(cos(angle), 0.0, sin(angle))
		var u := _mirror(float(i * TEXTURE_REPEATS) / SEGMENTS)
		vertices.append(around * low_radius + Vector3.UP * low_height)
		uvs.append(Vector2(u, low_v))
		vertices.append(around * high_radius + Vector3.UP * high_height)
		uvs.append(Vector2(u, high_v))
	for i in SEGMENTS:
		var a := 2 * i
		indices.append_array([a, a + 1, a + 2, a + 2, a + 1, a + 3])
	return _mesh(vertices, uvs, indices)


func _cloud_mesh(height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		vertices.append(Vector3((corner.x - 0.5) * SCALING, height, (corner.y - 0.5) * SCALING))
		uvs.append(corner * 4.0)
	return _mesh(vertices, uvs, PackedInt32Array([0, 2, 1, 0, 3, 2]))


func _mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
