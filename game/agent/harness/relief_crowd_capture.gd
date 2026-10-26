extends SceneTree

## RFC-067 P6: a crowd scene (default debug/bodies/body_gallery.tscn, every creature and wizard) shot from its own camera twice,
## relief off (`off.png`, normal_enabled cleared in memory on every material of scenes/bodies/materials) and on (`on.png`), plus
## `side_by_side.png`. Nothing is saved but the PNGs. Needs a window:
##   Godot --path . --fixed-fps 30 --resolution 1600x900 --script res://agent/harness/relief_crowd_capture.gd -- [--scene=res://...] [--out=res://agent/out/surface_batch] [--frames=60]

const MATERIALS := "res://scenes/bodies/materials/"
const TIMEOUT_S := 240.0

var _scene := "res://debug/bodies/body_gallery.tscn"
var _out := "res://agent/out/surface_batch"
var _frames := 60
var _mapped: Array[BaseMaterial3D] = []


func _initialize() -> void:
	create_timer(TIMEOUT_S).timeout.connect(quit.bind(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	for file in DirAccess.get_files_at(MATERIALS):
		var material := load(MATERIALS + file) as BaseMaterial3D if file.get_extension() == "tres" else null
		if material != null and material.normal_enabled:
			_mapped.append(material)
	print("RELIEF_CROWD materials with a normal map: %d" % _mapped.size())
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	change_scene_to_file(_scene)
	for i in _frames:
		await process_frame
	var shots := {}
	for on in [false, true]:
		for material in _mapped:
			material.normal_enabled = on
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var name := "on" if on else "off"
		image.save_png("%s/%s.png" % [_out, name])
		shots[name] = image
	var both := Image.create_empty(shots.off.get_width() * 2, shots.off.get_height(), false, shots.off.get_format())
	both.blit_rect(shots.off, Rect2i(Vector2i.ZERO, shots.off.get_size()), Vector2i.ZERO)
	both.blit_rect(shots.on, Rect2i(Vector2i.ZERO, shots.on.get_size()), Vector2i(shots.off.get_width(), 0))
	both.save_png(_out + "/side_by_side.png")
	print("RELIEF_CROWD wrote off.png on.png side_by_side.png in ", _out)
	quit()
