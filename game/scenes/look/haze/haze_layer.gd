class_name HazeLayer
extends Node3D

## The air between the camera and the land: a ground mist and the sun's god rays. `mist` is a
## FogVolume laid over the whole map (Terrain.bounds), its floor following the land under the camera
## (the map has heights from the void to the peaks), thicker near the ground and broken into banks
## by its noise texture, tinted with the biome's fog colour and drifting with `wind_m_s`; the
## volumetric fog pass draws it, so the sun, the spells and the creatures' lights shine through it.
## `god_rays` is a full-screen quad (god_rays.gdshader) fed the sun's direction and colour every
## frame: the sky behind rocks and trunks pours out as shafts toward the camera.
## Presentation only: nothing here is read by the simulation, and a headless or dedicated process
## frees it.

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var mist: FogVolume
@export var god_rays: MeshInstance3D
## How far (m) the mist box rises above the land under the camera; its density falls off toward
## the top.
@export_range(5.0, 200.0, 1.0, "suffix:m") var mist_height_m := 6.0
## How much of the biome's fog colour the mist takes (0 = white, 1 = the fog colour itself).
@export_range(0.0, 1.0, 0.01) var tint_share := 0.6
## The mist drifts this fast (m/s on x and z): its banks move across the land.
@export var wind_m_s := Vector2(0.6, 0.25)
## How fast (m/s) the mist's floor follows the land under the camera.
@export_range(0.5, 50.0, 0.5, "suffix:m/s") var follow_m_s := 6.0
## The sun (or the moon, ~0.28 at night) casts god rays while its energy is above this.
@export_range(0.0, 2.0, 0.01) var rays_min_sun_energy := 0.2

var _drift := Vector2.ZERO
var _base := Vector3.ZERO
var _floor_y := NAN
var _terrain: Terrain
var _rays_material: ShaderMaterial


func _ready() -> void:
	if not BodyLook.loads_meshes():
		queue_free()
		return
	if god_rays != null:
		_rays_material = god_rays.material_override as ShaderMaterial
		god_rays.extra_cull_margin = 16384.0
	_fit_mist.call_deferred()


func _process(delta: float) -> void:
	if mist != null and _terrain != null:
		_drift += wind_m_s * delta
		_follow_ground(delta)
		mist.global_position = Vector3(
			_base.x + _drift.x, _floor_y + mist_height_m * 0.5, _base.z + _drift.y
		)
		_tint_mist()
	_feed_rays()


## The mist covers the whole map (with a margin for the drift), from the lowest ground up.
func _fit_mist() -> void:
	if mist == null:
		return
	var terrain := Terrain.of(self)
	if terrain == null or not terrain.is_loaded():
		get_tree().create_timer(0.5).timeout.connect(_fit_mist)
		return
	var area := terrain.bounds().grow(200.0)
	mist.size = Vector3(area.size.x, mist_height_m, area.size.y)
	_base = Vector3(area.get_center().x, 0.0, area.get_center().y)
	_terrain = terrain


# The floor of the mist eases toward the land under the camera (a few metres below it, so the bank
# wraps the feet of what stands there).
func _follow_ground(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var y := _terrain.height_at(camera.global_position.x, camera.global_position.z)
	if is_nan(y):
		return
	var target := y - 2.0
	_floor_y = target if is_nan(_floor_y) else move_toward(_floor_y, target, follow_m_s * delta)


func _tint_mist() -> void:
	var fog := mist.material as FogMaterial
	var env := world_environment.environment if world_environment != null else null
	if fog == null or env == null:
		return
	fog.albedo = Color.WHITE.lerp(env.fog_light_color, tint_share)


func _feed_rays() -> void:
	if sun == null:
		return
	var lit := sun.visible and sun.light_energy >= rays_min_sun_energy
	if god_rays == null or _rays_material == null:
		return
	god_rays.visible = lit
	if not lit:
		return
	_rays_material.set_shader_parameter("sun_direction", sun.global_basis.z)
	_rays_material.set_shader_parameter("sun_color", sun.light_color)
