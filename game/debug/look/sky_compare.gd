extends Node

## Old sky (sky.tscn: meshes on a background colour) against the new one (sacrifice_sky.gdshader in a
## Sky resource), same god, same camera, same frozen second, in two SubViewports side by side.
## F6 shows god 0 and `check_tick` steps to the next; `-- --sky-compare-run` measures all of them and quits:
##   god  mean  p99  max  PASS/FAIL     (PASS: mean < 2 and max < 6, CIE76 over every pixel of every pose)

const ThemeApplier := preload("res://scenes/look/theme/theme_applier.gd")
const FROZEN_SECONDS := 100.0
const MAX_MEAN := 2.0
const MAX_PEAK := 6.0
const SETTLE_FRAMES := 3
## Where sky.gd puts its origin: the new shader's eye height is measured from here.
const BASE_HEIGHT_M := -511.0

## (yaw, pitch) in degrees. Horizon and upper band, clouds, and the lower band.
@export var poses: Array[Vector2] = [Vector2(0.0, 5.0), Vector2(135.0, 35.0), Vector2(270.0, -15.0)]
@export var camera_height_m := 40.0

@export var old_viewport: SubViewport
@export var new_viewport: SubViewport
@export var old_environment: WorldEnvironment
@export var old_camera: Camera3D
@export var new_camera: Camera3D
@export var old_sky: Node3D
@export var new_environment: WorldEnvironment

var _index := 0


func _ready() -> void:
	new_environment.environment.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	if OS.get_cmdline_user_args().has("--sky-compare-run"):
		_measure_all.call_deferred()
	else:
		_show.call_deferred(GameData.gods()[0], poses[0])


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
	var theme := ThemeApplier.theme_for(god)
	if theme == null:
		return
	var resolved: Resource = theme.resolved()
	_point_cameras(pose)
	_set_old(resolved)
	_set_new(resolved)
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw


func _point_cameras(pose: Vector2) -> void:
	for camera in [old_camera, new_camera]:
		camera.position = Vector3(0.0, camera_height_m, 0.0)
		camera.rotation_degrees = Vector3(pose.y, -pose.x, 0.0)


func _set_old(theme: Resource) -> void:
	old_sky.set_process(false)
	old_sky.set("background_color", theme.background_color)
	old_sky.set_textures(theme.file("skyt.png"), theme.file("skyb.png"), theme.file("sky.png"))
	old_sky.set_time(FROZEN_SECONDS)
	old_environment.environment.background_color = theme.background_color


func _set_new(theme: Resource) -> void:
	var material := new_environment.environment.sky.sky_material as ShaderMaterial
	material.set_shader_parameter("background_color", theme.background_color)
	material.set_shader_parameter("top_texture", load(theme.file("skyt.png")))
	material.set_shader_parameter("bottom_texture", load(theme.file("skyb.png")))
	material.set_shader_parameter("clouds_texture", load(theme.file("sky.png")))
	material.set_shader_parameter("eye_height_m", camera_height_m - BASE_HEIGHT_M)
	material.set_shader_parameter("time_override_s", FROZEN_SECONDS)
