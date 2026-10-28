class_name LightShafts
extends MultiMeshInstance3D

## Faked shafts of sunlight hanging from the sky around the camera (light_shaft.gdshader): lit
## planes that lean along the sun's light and turn to face the camera, so they read from any side,
## not only when the sun is on the screen. The world is cut in `cell_m` squares; a hash of each
## square near the camera says whether a shaft stands there and its place, size and phase, so a
## shaft stays where it is while the camera moves and comes back the same when it returns.
## HazeLayer feeds the sun (`set_sun`). Presentation only.

## Side (m) of the squares the shafts are scattered over.
@export_range(10.0, 200.0, 1.0, "suffix:m") var cell_m := 40.0
## Squares within this distance (m) of the camera may hold a shaft.
@export_range(20.0, 400.0, 1.0, "suffix:m") var reach_m := 150.0
## Share of the squares that hold one.
@export_range(0.0, 1.0, 0.01) var share := 0.22
@export_range(1.0, 60.0, 0.5, "suffix:m") var min_width_m := 3.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var max_width_m := 7.0
@export_range(10.0, 300.0, 1.0, "suffix:m") var min_length_m := 55.0
@export_range(10.0, 300.0, 1.0, "suffix:m") var max_length_m := 95.0
## Most shafts at once.
@export_range(1, 64) var max_shafts := 24

var _cell := Vector2i(1 << 30, 1 << 30)
var _material: ShaderMaterial
var _sun_direction := Vector3(0.3, 0.8, 0.4)


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = max_shafts
	mm.visible_instance_count = 0
	multimesh = mm
	_material = material_override as ShaderMaterial
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := camera.global_position
	var cell := Vector2i(floori(at.x / cell_m), floori(at.z / cell_m))
	if cell != _cell:
		_cell = cell
		_scatter(at)


## The sun the shafts lean along and take their colour from; `strength` 0 hides them (night).
func set_sun(direction: Vector3, color: Color, strength: float) -> void:
	visible = strength > 0.0
	if _material == null:
		return
	if direction.distance_to(_sun_direction) > 0.001:
		_sun_direction = direction
		_cell = Vector2i(1 << 30, 1 << 30)
	_material.set_shader_parameter("sun_direction", direction)
	_material.set_shader_parameter("sun_color", color * strength)


func _scatter(at: Vector3) -> void:
	var terrain := Terrain.of(self)
	var cells := ceili(reach_m / cell_m)
	var count := 0
	for x in range(_cell.x - cells, _cell.x + cells + 1):
		for z in range(_cell.y - cells, _cell.y + cells + 1):
			if count >= max_shafts:
				break
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2i(x, z))
			if rng.randf() > share:
				continue
			var foot := Vector3((x + rng.randf()) * cell_m, 0.0, (z + rng.randf()) * cell_m)
			if Vector2(foot.x - at.x, foot.z - at.z).length() > reach_m:
				continue
			var ground := terrain.height_at(foot.x, foot.z) if terrain != null else at.y
			if is_nan(ground):
				continue
			foot.y = ground
			var length := rng.randf_range(min_length_m, max_length_m)
			var top := foot + _sun_direction.normalized() * length
			multimesh.set_instance_transform(count, Transform3D(Basis(), top))
			multimesh.set_instance_custom_data(
				count,
				Color(
					rng.randf_range(min_width_m, max_width_m),
					length,
					rng.randf() * TAU,
					rng.randf_range(0.6, 1.0)
				)
			)
			count += 1
	multimesh.visible_instance_count = count
