extends Node

## Grass laboratory (RFC-022e): a small ground patch of Persephone's valley (no map, no world),
## a free camera, a few creatures walking through the grass, a sun you can turn, and the grass
## sun to turn. Memory-safe: caps the blades drawn and watches the process memory.
## The GrassSet and GrassType are the real ones (`@export grass_set`), so editing them in the
## inspector (editor: F6 then the Remote tree, or while it runs) shows live.
##
## Keys: C camera (free / game) - RMB drag orbit - wheel zoom - WASD move - Q/E up, down
##       F3 next quality preset (the grass itself is edited in the inspector)
##       R/F turn the sun left/right - T/G sun higher/lower - Y creatures walk on/off
##       H hide/show the info text - O/P wind direction

const QUALITY_IDS: Array[StringName] = [&"low", &"medium", &"high"]
const CREATURE_MODELS: Array[String] = ["ycro", "amuh", "apez", "jnwr"]
## Hard limits of the lab.
const MAX_BLADES := 60000
const MAX_RADIUS_M := 100.0
const MAX_NEAR_RADIUS_M := 14.0
const SOFT_MEMORY_MB := 2000.0
const HARD_MEMORY_MB := 2500.0

@export var ground: GrassLabGround
@export var rig: LookRig
@export var game_camera: Camera3D
@export var body_scene: PackedScene
@export var lab_camera: Camera3D
@export var info: Label
@export var creatures: Node3D
## The rig's sun, which the keys turn (taken from the rig when the lab starts).
var sun: DirectionalLight3D
## The set the biome uses: edit its types here, in the inspector, and the grass follows.
@export var grass_set: GrassSet
@export var center := Vector2(1500.0, 1500.0)
## How far from the center the camera target may go (the patch is 130 m wide).
@export var roam_m := 18.0
@export var creature_count := 4
@export var walk_speed := 2.2

var _target := Vector3(1500.0, 19.0, 1500.0)
var _yaw := 0.6
var _pitch := -0.3
var _distance := 9.0
var _quality_index := 1
var _walking := true
var _game_camera := false
var _time := 0.0
var _show_info := true
var _frame_ms := 16.0
var _density_cap := 1.0
var _guard_timer := 0.0
var _quality: LookQuality


func _ready() -> void:
	rig.terrain = ground as MeshInstance3D
	sun = rig.sun_layer.sun
	var profile := GameCatalog.shared().god("persephone").look
	grass_set = profile.grass
	ground.tiles = rig.tile_map
	_read_args()
	_apply_quality.call_deferred()
	_settle.call_deferred()
	rig.apply_profile.call_deferred(profile)


## Command line (for captures): --quality=low|medium|high --cam=game|free
## --yaw=deg --pitch=deg --dist=m --sun=deg --shot=path (saves after 150 frames and quits).
var _shot_path := ""
var _frames := 0


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			_quality_index = maxi(QUALITY_IDS.find(StringName(value)), 0)
		elif arg == "--cam=game":
			_pending_game_cam = true
		elif arg.begins_with("--yaw="):
			_yaw = deg_to_rad(float(value))
		elif arg.begins_with("--pitch="):
			_pitch = deg_to_rad(float(value))
		elif arg.begins_with("--dist="):
			_distance = float(value)
		elif arg.begins_with("--sunpitch="):
			_pending_sun_pitch = deg_to_rad(float(value))
		elif arg.begins_with("--sun="):
			_pending_sun = deg_to_rad(float(value))
		elif arg == "--grass=off":
			_grass_off = true
		elif arg.begins_with("--seq="):
			_seq_dir = value
		elif arg.begins_with("--shot="):
			_shot_path = value


var _seq_dir := ""
var _grass_off := false
var _pending_game_cam := false
var _pending_sun := 0.0
var _pending_sun_pitch := 0.0


func _settle() -> void:
	await get_tree().process_frame
	_spawn_creatures()
	_frame_target()
	if _pending_game_cam:
		_toggle_camera()
	if _pending_sun != 0.0 or _pending_sun_pitch != 0.0:
		_turn_sun(_pending_sun, _pending_sun_pitch)


func _spawn_creatures() -> void:
	for i in creature_count:
		var body: Node3D = body_scene.instantiate()
		body.get_node("Visual").set("model", CREATURE_MODELS[i % CREATURE_MODELS.size()])
		creatures.add_child(body)
		body.add_to_group("unit")
		body.get_node("Name").visible = false
		body.set_meta(&"phase", float(i) / float(creature_count) * TAU)
		_place(body, center + Vector2(cos(i * 1.6), sin(i * 1.6)) * 5.0)


func _place(unit: Node3D, at: Vector2) -> void:
	unit.global_position = Vector3(at.x, ground.shape.height_at(at.x, at.y), at.y)


func _process(delta: float) -> void:
	_time += delta
	_frame_ms = lerpf(_frame_ms, delta * 1000.0, 0.05)
	_walk_creatures()
	if _game_camera:
		_follow_leader()
	else:
		_move_camera(delta)
	_frames += 1
	if _seq_dir != "" and _frames >= 120 and (_frames - 120) % 12 == 0:
		var n := (_frames - 120) / 12
		get_viewport().get_texture().get_image().save_png("%s/seq_%d.png" % [_seq_dir, n])
		_target += Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * 3.0
		if n >= 5:
			get_tree().quit()
	if _frames == 140 and _shot_path != "":
		print("LABPERF fps %d ms %.1f mem_mb %.0f video_mb %.0f prim_k %d" % [Engine.get_frames_per_second(), _frame_ms, OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)])
	if _shot_path != "" and _frames == 150:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()
	_guard_timer -= delta
	if _guard_timer <= 0.0:
		_guard_timer = 1.0
		_guard_memory()
	_update_info()


func _walk_creatures() -> void:
	if not _walking:
		return
	for unit in creatures.get_children():
		var phase: float = unit.get_meta(&"phase", 0.0)
		var radius := 7.0 + 3.0 * sin(phase * 2.0)
		var angle := phase + _time * walk_speed / radius
		var at := center + Vector2(cos(angle), sin(angle)) * radius
		var ahead := center + Vector2(cos(angle + 0.05), sin(angle + 0.05)) * radius
		_place(unit, at)
		var dir := Vector3(ahead.x - at.x, 0.0, ahead.y - at.y)
		if dir.length() > 0.001:
			unit.look_at(unit.global_position + dir, Vector3.UP)


func _move_camera(delta: float) -> void:
	var move := Vector3.ZERO
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	if Input.is_key_pressed(KEY_W):
		move += forward
	if Input.is_key_pressed(KEY_S):
		move -= forward
	if Input.is_key_pressed(KEY_D):
		move += right
	if Input.is_key_pressed(KEY_A):
		move -= right
	if Input.is_key_pressed(KEY_E):
		move += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		move -= Vector3.UP
	_target += move * delta * maxf(_distance, 3.0) * 0.9
	_target.x = clampf(_target.x, center.x - roam_m, center.x + roam_m)
	_target.z = clampf(_target.z, center.y - roam_m, center.y + roam_m)
	_target.y = clampf(_target.y, ground.shape.height_at(_target.x, _target.z) - 1.0, ground.shape.height_at(_target.x, _target.z) + 40.0)
	_frame_target()


func _frame_target() -> void:
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	lab_camera.global_position = _target + basis.z * _distance
	lab_camera.global_basis = basis


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _game_camera:
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(_pitch - event.relative.y * 0.005, -1.45, 0.4)
	elif event is InputEventMouseButton and event.pressed and not _game_camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance * 0.9, 1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance * 1.1, 120.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(key: Key) -> void:
	match key:
		KEY_C:
			_toggle_camera()
		KEY_F3:
			_quality_index = (_quality_index + 1) % QUALITY_IDS.size()
			_apply_quality()
		KEY_R:
			_turn_sun(0.12, 0.0)
		KEY_F:
			_turn_sun(-0.12, 0.0)
		KEY_T:
			_turn_sun(0.0, 0.08)
		KEY_G:
			_turn_sun(0.0, -0.08)
		KEY_Y:
			_walking = not _walking
		KEY_H:
			_show_info = not _show_info
			info.visible = _show_info
		KEY_O:
			_turn_wind(15.0)
		KEY_P:
			_turn_wind(-15.0)


func _toggle_camera() -> void:
	_game_camera = not _game_camera
	(game_camera if _game_camera else lab_camera).make_current()


## A camera like the game's: behind and above the first creature, looking over its shoulder.
func _follow_leader() -> void:
	if creatures.get_child_count() == 0:
		return
	var leader := creatures.get_child(0) as Node3D
	var back := leader.global_basis.z
	game_camera.global_position = leader.global_position + back * 4.2 + Vector3.UP * 2.4
	game_camera.look_at(leader.global_position + Vector3.UP * 1.2 - back * 4.0, Vector3.UP)


func _turn_wind(degrees: float) -> void:
	var type := grass_set.primary() if grass_set else null
	if type:
		type.wind_direction_deg = fposmod(type.wind_direction_deg + degrees, 360.0)


func _turn_sun(yaw: float, pitch: float) -> void:
	sun.rotate_y(yaw)
	sun.rotation.x = clampf(sun.rotation.x + pitch, -1.5, -0.05)


func _apply_quality() -> void:
	_quality = (load("res://data/look/quality_%s.tres" % QUALITY_IDS[_quality_index]) as LookQuality).duplicate() as LookQuality
	_quality.grass_radius_m = minf(_quality.grass_radius_m, MAX_RADIUS_M)
	_quality.grass_near_radius_m = minf(_quality.grass_near_radius_m, MAX_NEAR_RADIUS_M)
	_quality.grass_density_scale = minf(_quality.grass_density_scale, _density_cap)
	# Estimated blades drawn: near disc at full density, a ring thinning to the far density.
	var type := grass_set.primary()
	while type and _quality.grass_density_scale > 0.05 and _visible_blades(type) > MAX_BLADES:
		_quality.grass_density_scale *= 0.85
	_quality.grass_enabled = not _grass_off
	rig.apply_quality(_quality)
	QualityApplier.apply_to(get_viewport(), _quality)


func _visible_blades(type: GrassType) -> float:
	var near := _quality.grass_near_radius_m
	var radius := _quality.grass_radius_m
	var scale := _quality.grass_density_scale
	var area_near := PI * near * near
	var area_ring := PI * (radius * radius - near * near) * 0.6
	return (type.density_near * area_near + type.density_far * area_ring * 0.7) * scale * 0.5


func _guard_memory() -> void:
	var mb := OS.get_static_memory_usage() / 1048576.0
	if mb > HARD_MEMORY_MB:
		push_error("grass_lab: memoria %.0f MB sobre el limite (%.0f MB): cierro." % [mb, HARD_MEMORY_MB])
		get_tree().quit(1)
	elif mb > SOFT_MEMORY_MB and _density_cap > 0.1:
		_density_cap *= 0.5
		push_warning("grass_lab: memoria %.0f MB: bajo la densidad a x%.2f." % [mb, _density_cap])
		_apply_quality()


func _update_info() -> void:
	if not _show_info:
		return
	var type := grass_set.primary() if grass_set else null
	info.text = "calidad %s | pasto: %s | camara %s | %d fps | %.1f ms\nmemoria %.0f MB | video %.0f MB | draw %d | prim %dk | densidad x%.2f | radio %.0f m\n%s" % [
		QUALITY_IDS[_quality_index], type.label if type else "ninguno", "juego" if _game_camera else "libre",
		Engine.get_frames_per_second(), _frame_ms,
		OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		_quality.grass_density_scale if _quality else 0.0, _quality.grass_radius_m if _quality else 0.0,
		"C camara | clic der: orbitar | rueda | WASD QE | F3 calidad | R/F T/G sol | Y criaturas | O/P viento | H texto"]
