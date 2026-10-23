extends Node

## Old sky (debug/look/sky_reference/sky.tscn: meshes on a background colour, frozen here as the reference) against the
## new one (sacrifice_sky.gdshader in a Sky resource), same god, same camera, same frozen second, in two SubViewports
## side by side. Both are fed from the god's own `look.sky.material` (colour and the three textures), minus its aurora
## (the old sky has none), so what is measured is the picture, not the data.
## F6 shows god 0 and `check_tick` steps to the next; `-- --sky-compare-run` measures all of them and quits:
##   god  mean  p99  max  PASS/FAIL     (PASS: mean < 2 and max < 6, CIE76 over every pixel of every pose)
## `-- --sky-compare-size=1280x720` renders both skies that big (default 320x180): if the residual shrinks with the size it was
## sampling (mip level, edges); if it stays it is geometry.

const FROZEN_SECONDS := 100.0
const MAX_MEAN := 2.0
const MAX_PEAK := 6.0
const SETTLE_FRAMES := 3
## Where the reference sky puts its origin: the new shader's eye height is measured from here.
const BASE_HEIGHT_M := -511.0

## (yaw, pitch) in degrees. Horizon and upper band, clouds, and the lower band.
@export var poses: Array[Vector2] = [Vector2(0.0, 5.0), Vector2(135.0, 35.0), Vector2(270.0, -15.0)]
@export var camera_height_m := 40.0
## Pixels of each viewport; the containers do not stretch them, so this is really what is rendered.
@export var viewport_size := Vector2i(320, 180)

@export var old_viewport: SubViewport
@export var new_viewport: SubViewport
@export var old_environment: WorldEnvironment
@export var old_camera: Camera3D
@export var new_camera: Camera3D
@export var old_sky: Node3D
@export var new_environment: WorldEnvironment

var _index := 0


func _ready() -> void:
	_size_viewports()
	new_environment.environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	if OS.get_cmdline_user_args().has("--sky-compare-run"):
		_measure_all.call_deferred()
	else:
		_show.call_deferred(GameData.gods()[0], poses[0])


func _size_viewports() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sky-compare-size="):
			var parts := arg.get_slice("=", 1).split("x")
			if parts.size() == 2:
				viewport_size = Vector2i(int(parts[0]), int(parts[1]))
	for viewport in [old_viewport, new_viewport]:
		(viewport.get_parent() as SubViewportContainer).stretch = false
		viewport.size = viewport_size
	print("sky_compare viewport %dx%d" % [viewport_size.x, viewport_size.y])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_index = (_index + 1) % GameData.gods().size()
		_show(GameData.gods()[_index], poses[0])


func _measure_all() -> void:
	var failed := false
	print("god meanDE p99DE maxDE verdict")
	for god in GameData.gods():
		var means := 0.0
		var p99 := 0.0
		var peak := 0.0
		for pose in poses:
			await _show(god, pose)
			var result := SkyDeltaE.compare(old_viewport.get_texture().get_image(), new_viewport.get_texture().get_image())
			means += result.mean / poses.size()
			p99 = maxf(p99, result.p99)
			peak = maxf(peak, result.max)
			print("  %s pose %s mean %.2f p99 %.2f max %.2f" % [god, pose, result.mean, result.p99, result.max])
		var passed := means < MAX_MEAN and peak < MAX_PEAK
		failed = failed or not passed
		print("%s %.2f %.2f %.2f %s" % [god, means, p99, peak, "PASS" if passed else "FAIL"])
	get_tree().quit(1 if failed else 0)


func _show(god: StringName, pose: Vector2) -> void:
	var look := GameCatalog.shared().god(String(god)).look
	if look == null or look.sky == null or look.sky.material == null:
		return
	_point_cameras(pose)
	_set_old(look.sky.material)
	_set_new(look.sky.material)
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw


func _point_cameras(pose: Vector2) -> void:
	for camera in [old_camera, new_camera]:
		camera.position = Vector3(0.0, camera_height_m, 0.0)
		camera.rotation_degrees = Vector3(pose.y, -pose.x, 0.0)


func _set_old(material: ShaderMaterial) -> void:
	var background: Color = material.get_shader_parameter("background_color")
	old_sky.set_process(false)
	old_sky.set("background_color", background)
	old_sky.set_textures(_path(material, "top_texture"), _path(material, "bottom_texture"), _path(material, "clouds_texture"))
	old_sky.set_time(FROZEN_SECONDS)
	old_environment.environment.background_color = background


func _set_new(material: ShaderMaterial) -> void:
	var copy := material.duplicate() as ShaderMaterial
	copy.set_shader_parameter("eye_height_m", camera_height_m - BASE_HEIGHT_M)
	copy.set_shader_parameter("time_override_s", FROZEN_SECONDS)
	copy.set_shader_parameter("aurora_strength", 0.0)
	new_environment.environment.sky.sky_material = copy


func _path(material: ShaderMaterial, uniform: String) -> String:
	return (material.get_shader_parameter(uniform) as Texture2D).resource_path
