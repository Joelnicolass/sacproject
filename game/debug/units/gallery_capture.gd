class_name GalleryCapture
extends Node

## Observation helper of the death galleries (death_ragdoll, death_ragdoll_wizards): follows ONE body with the camera from a
## 3/4 view, and saves PNGs of the viewport at fixed intervals from the moment the gallery says the body died, then quits.
## It never touches a body: the gallery hands it the `subject` and calls `begin_capture()`.
## Command line (after `--`): --distance=<m> --out=<dir> --shots=<n> --every=<s>. Headless has no picture: it runs the
## same clock, prints what it would have saved and quits.

## The gallery's camera; this node is the only one that moves it.
@export var camera: Camera3D
## Meters from the chest of the subject to the camera.
@export_range(2.0, 30.0, 0.5, "suffix:m") var distance_m := 7.0
## Height above the subject's feet the camera looks at.
@export_range(0.0, 4.0, 0.1, "suffix:m") var look_height_m := 1.3
## Camera pitch over the ground and yaw around the subject (40 = a 3/4 view from the front).
@export_range(0.0, 80.0, 1.0, "suffix:°") var pitch_deg := 20.0
@export_range(-180.0, 180.0, 1.0, "suffix:°") var yaw_deg := 40.0
## Where the PNGs go; empty = no capture.
@export var out_dir := ""
## How many PNGs (0 = none, the gallery keeps looping) and the seconds between two.
@export_range(0, 200) var shots := 0
@export_range(0.1, 30.0, 0.1, "suffix:s") var every_s := 1.0

## The body the camera follows; null leaves the camera where the scene put it.
var subject: Node3D
var _capturing := false


## The value of `--<name>=...` in the user args, or `fallback`.
static func cli(arg_name: String, fallback: String = "") -> String:
	var prefix := "--%s=" % arg_name
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return fallback


func _ready() -> void:
	distance_m = float(cli("distance", str(distance_m)))
	out_dir = cli("out", out_dir)
	shots = int(cli("shots", str(shots)))
	every_s = float(cli("every", str(every_s)))


func _process(_delta: float) -> void:
	if camera == null or subject == null or not is_instance_valid(subject):
		return
	var look_at := subject.global_position + Vector3.UP * look_height_m
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance_m
	camera.global_position = look_at + offset
	camera.look_at(look_at)


## The subject just died: saves `shots` PNGs, the first now and one more every `every_s`, then quits the process.
func begin_capture() -> void:
	if shots <= 0 or out_dir.is_empty() or _capturing:
		return
	_capturing = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	for i in shots:
		if i > 0:
			await get_tree().create_timer(every_s).timeout
		await _save(i, i * every_s)
	print("capture done: %d shots in %s" % [shots, out_dir])
	get_tree().quit()


func _save(index: int, since_death_s: float) -> void:
	var file := out_dir.path_join("shot_%02d_t%04.1f.png" % [index, since_death_s])
	if DisplayServer.get_name() == "headless":
		print("capture (headless, not saved): %s" % file)
		return
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(file)
	print("capture %s (%s)" % [file, error_string(error)])
