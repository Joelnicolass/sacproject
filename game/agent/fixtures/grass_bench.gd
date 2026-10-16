extends Node

## Agent only (022e4c): the deterministic grass bench. Everything that moves is held still (own
## camera, wizard teleported and idle, shader time frozen, engine time stopped while shooting, no
## HUD, original sky stopped) and, for each view, the SAME frame is saved with the blades (A), with
## the blades hidden but the ground paint intact (B), again with the blades (A2: determinism
## control) and, at the end, with the grass layer off (C). The blades are the only difference between
## A and B, so the sky, props and the wizard cancel in the metrics. Also saves what the metrics need
## to mask by geometry (the baked height map, the baked zone data, the camera of every shot) and the
## primitives of the frame in A and B. The sweep walks and turns the camera in `sweep_steps` frames
## to look for pop. `agent/grass_bench_metrics.py` reads it all.
## Run: agent/run_rfc022e4.sh rfc022e4c_bench_pyro.json <outdir> [--preset=low|medium|high]
## (it quits by itself).

const OUT_SIZE := Vector2i(1152, 648)

@export var world: Node
@export var views: Array[GrassBenchView] = []
## The sweep starts from this view.
@export var sweep_view: GrassBenchView
## Applied to the rig before shooting (empty = the world's own, medium). `--preset=` overrides it.
@export var preset: LookQuality
@export var settle_s := 8.0
@export var converge_s := 2.5
@export var sweep_steps := 24
@export var sweep_settle_s := 0.9
## Forward step (m) and turn (deg) per sweep frame.
@export var sweep_step_m := 0.75
@export var sweep_turn_deg := 3.0

var _out := "res://agent/out/rfc022e4c/bench"
var _field: Node
var _terrain: Node
var _wizard: Node3D
var _camera: Camera3D
var _shots := {}
var _prims := {}
var _window_info := {}
## Quick runs while tuning: only these views (`--only=a,b`), no sweep (`--no-sweep`), no C shots (`--no-c`).
var _only: Array = []
var _skip_c := false
## Diagnosis only (`--no-ssao`): the environment's SSAO off, to tell its halos from the blades.
var _no_ssao := false
## Diagnosis only (`--fade-probe`): every blade fully in its color fade (drawn as the ground it hides)
## and tall, to measure how exactly a faded blade matches the ground.
var _fade_probe := false
## Diagnosis only (`--grass-param=name:value`, repeatable): a uniform of the grass material, set after the freeze.
var _grass_params := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--only="):
			_only = arg.get_slice("=", 1).split(",")
		elif arg == "--no-sweep":
			sweep_steps = 0
		elif arg == "--no-c":
			_skip_c = true
		elif arg == "--no-ssao":
			_no_ssao = true
		elif arg == "--fade-probe":
			_fade_probe = true
		elif arg.begins_with("--grass-param="):
			var pair := arg.get_slice("=", 1).split(":")
			_grass_params[pair[0]] = str_to_var(pair[1])
		elif arg.begins_with("--preset="):
			var path := "res://data/look/quality_%s.tres" % arg.get_slice("=", 1)
			if ResourceLoader.exists(path):
				preset = load(path)
	if not _only.is_empty():
		var keep: Array[GrassBenchView] = []
		for view in views:
			if view.label in _only:
				keep.append(view)
		views = keep
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run()


func _run() -> void:
	await _wait(settle_s)
	var rig := world.get_node_or_null("Look")
	_field = get_tree().get_first_node_in_group("grass_field")
	_terrain = get_tree().get_first_node_in_group("terrain")
	_wizard = get_tree().get_first_node_in_group("local_wizard") as Node3D
	if rig == null or _field == null or _terrain == null or _wizard == null:
		print("GRASSBENCH missing nodes ", rig, _field, _terrain, _wizard)
		get_tree().quit(1)
		return
	if preset:
		rig.call("apply_quality", preset)
		await _wait(converge_s + 2.0)
		_field = get_tree().get_first_node_in_group("grass_field")
	_freeze()
	var hud := world.get_node_or_null("Hud")
	if hud:
		hud.visible = false
	_camera = Camera3D.new()
	_camera.far = 4000.0
	add_child(_camera)
	_camera.current = true
	_window_info = {
		"window": [get_window().size.x, get_window().size.y],
		"visible_rect": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"scale_3d": get_viewport().scaling_3d_scale}
	print("GRASSBENCH ", _window_info)
	_dump_maps()
	for view in views:
		await _shoot_view(view)
	if sweep_view and sweep_steps > 0:
		await _sweep()
	if not _skip_c:
		rig.call("set_layer_enabled", 3, false)
		await _wait(1.2)
		for view in views:
			_place(view)
			await _settle(false)
			_stop_time(true)
			await _save("%s_C.png" % view.label)
			_stop_time(false)
	_write_json()
	print("GRASSBENCH done")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Frozen wind, ground wave bands and sky: the only thing that may move between two shots is nothing.
func _freeze() -> void:
	# The temporal upscaler (FSR2 of the medium preset) jitters the image every frame: A and A2 would
	# differ by noise that reads as loose blades. Same internal resolution, plain bilinear upscale.
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var material := _field.get("_material") as ShaderMaterial
	material.set_shader_parameter("time_override", 1.0)
	print("GRASSBENCH fade_roughness=", material.get_shader_parameter("fade_roughness"), " fade_specular=", material.get_shader_parameter("fade_specular"))
	for key in _grass_params:
		material.set_shader_parameter(key, _grass_params[key])
	if _fade_probe:
		material.set_shader_parameter("fade_start", 0.0)
		material.set_shader_parameter("color_fade_start", 0.0)
		material.set_shader_parameter("color_fade_end", 0.002)
		material.set_shader_parameter("fade_end", 50.0)
	var ground := _terrain.get("material_override") as ShaderMaterial
	if ground:
		ground.set_shader_parameter("grass_time_override", 1.0)
	var classic: Variant = _terrain.call("classic_material") if _terrain.has_method("classic_material") else null
	if classic:
		(classic as ShaderMaterial).set_shader_parameter("grass_time_override", 1.0)
	var sky := world.get_node_or_null("Sky")
	if sky:
		sky.set_process(false)
	if _no_ssao:
		var env := get_viewport().find_world_3d().environment
		if env == null and get_viewport().get_camera_3d():
			env = get_viewport().get_camera_3d().environment
		for node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			env = (node as WorldEnvironment).environment
		if env:
			env.ssao_enabled = false
		print("GRASSBENCH ssao off ", env)


## The engine clock stops while a frame is shot (animations, particles, shader TIME); it runs while
## the field converges on the camera.
func _stop_time(stopped: bool) -> void:
	Engine.time_scale = 0.0 if stopped else 1.0


func _ground_y(x: float, z: float) -> float:
	var y: float = _terrain.call("ground_height", x, z)
	return 0.0 if is_nan(y) else y


func _place(view: GrassBenchView) -> void:
	var y := _ground_y(view.spot.x, view.spot.y)
	_wizard.global_position = Vector3(view.spot.x, y + 0.3, view.spot.y)
	_wizard.rotation.y = deg_to_rad(view.yaw_deg)
	_aim(view.eye, view.target, view.fov)


func _aim(eye: Vector3, target: Vector3, fov: float) -> void:
	var from := Vector3(eye.x, _ground_y(eye.x, eye.z) + eye.y, eye.z)
	var to := Vector3(target.x, _ground_y(target.x, target.z) + target.y, target.z)
	_camera.fov = fov
	_camera.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(to, Vector3.UP)
	_camera.make_current()


## Waits for the field to follow the camera; `stop` leaves the field frozen so no cell moves between shots.
func _settle(stop: bool, seconds := -1.0) -> void:
	_stop_time(false)
	_field.set_process(true)
	await _wait(converge_s if seconds < 0.0 else seconds)
	if stop:
		_field.set_process(false)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != OUT_SIZE:
		image.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(_out.path_join(file_name)))


func _blades(visible_now: bool) -> void:
	var cells: Dictionary = _field.get("_cells")
	for key in cells:
		var node: Node3D = cells[key]
		if is_instance_valid(node):
			node.visible = visible_now


func _prim_count() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


## A, B and A2 of the current camera; records the camera and the primitives.
func _shoot(label: String, with_prims := true) -> void:
	_stop_time(true)
	# A few frames with the clock stopped so every temporal effect (exposure, shadows) has settled.
	for i in 6:
		await RenderingServer.frame_post_draw
	await _save("%s_A.png" % label)
	_shots[label] = _camera_info()
	if with_prims:
		_prims[label] = {"A": _prim_count()}
	_blades(false)
	await _save("%s_B.png" % label)
	if with_prims:
		_prims[label]["B"] = _prim_count()
	_blades(true)
	if with_prims:
		await _save("%s_A2.png" % label)


func _shoot_view(view: GrassBenchView) -> void:
	print("GRASSBENCH view ", view.label)
	_place(view)
	await _settle(true)
	print("GRASSBENCH settled ", view.label)
	await _shoot(view.label)
	_stop_time(false)


func _sweep() -> void:
	var base := sweep_view
	_place(base)
	var forward := Vector3(base.target.x - base.eye.x, 0.0, base.target.z - base.eye.z).normalized()
	for i in sweep_steps:
		var step := forward.rotated(Vector3.UP, deg_to_rad(-sweep_turn_deg * i))
		var eye := base.eye + forward * sweep_step_m * i
		var target := eye + step * 30.0
		target.y = base.target.y
		_aim(eye, target, base.fov)
		await _settle(true, sweep_settle_s)
		await _shoot("sweep_%02d" % i, false)


## Everything the metrics need to mask by geometry.
func _camera_info() -> Dictionary:
	var basis := _camera.global_transform.basis
	var origin: Vector3 = _field.global_position
	var scale := Vector2(OUT_SIZE) / get_viewport().get_visible_rect().size
	var box := _wizard_box().grow(0.0)
	return {
		"eye": _vec(_camera.global_position - origin),
		"right": _vec(basis.x), "up": _vec(basis.y), "forward": _vec(-basis.z),
		"fov": _camera.fov,
		"wizard_box": [box.position.x * scale.x, box.position.y * scale.y, box.end.x * scale.x, box.end.y * scale.y]}


func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _wizard_box() -> Rect2:
	var low := _wizard.global_position
	var rect := Rect2()
	var first := true
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var corner := low + Vector3(-2.5 + 5.0 * ix, 5.0 * iy, -2.5 + 5.0 * iz)
				if _camera.is_position_behind(corner):
					continue
				var screen := _camera.unproject_position(corner)
				if first:
					rect = Rect2(screen, Vector2.ZERO)
					first = false
				else:
					rect = rect.expand(screen)
	return rect.grow(maxf(rect.size.x, rect.size.y) * 0.1 + 6.0)


## The baked height map (raw float32, 1024 x 1024, row 0 = z 0) and the baked zone data (PNG).
func _dump_maps() -> void:
	var image: Image = _field.get("_height_image")
	var buffer := PackedFloat32Array()
	buffer.resize(image.get_width() * image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			buffer[y * image.get_width() + x] = image.get_pixel(x, y).r
	var file := FileAccess.open(ProjectSettings.globalize_path(_out.path_join("height_r.f32")), FileAccess.WRITE)
	file.store_buffer(buffer.to_byte_array())
	file.close()
	var zone := (_field.get("_material") as ShaderMaterial).get_shader_parameter("zone_data") as Texture2D
	if zone:
		zone.get_image().save_png(ProjectSettings.globalize_path(_out.path_join("zone_data.png")))


func _write_json() -> void:
	var quality: Variant = _field.get("_preset")
	var type: Variant = _field.get("_type")
	var info := {
		"views": views.map(func(v: GrassBenchView) -> String: return v.label),
		"sweep_steps": sweep_steps if sweep_view else 0,
		"shots": _shots, "prims": _prims,
		"size": [OUT_SIZE.x, OUT_SIZE.y],
		"map_m": 2560.0, "height_texels": 1024,
		"preset": String(quality.get("id")) if quality else "",
		"radius_m": float(quality.get("grass_radius_m")) if quality else 45.0,
		"near_radius_m": float(quality.get("grass_near_radius_m")) if quality else 15.0,
		"fade_end": 0.85,
		"fade_start": float(type.get("fade_start")) if type and type.get("fade_start") != null else 0.353,
		"window": _window_info, "upscaler": "bilinear (forced by the bench: FSR2 jitters between frames)"}
	var file := FileAccess.open(ProjectSettings.globalize_path(_out.path_join("bench.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "  "))
	file.close()
