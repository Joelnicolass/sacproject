extends Node

## Agent only (022e4 far patterns): in ONE run, with the camera still, saves a frame, switches a
## grass term off, saves another, and so on (`diag_NN_<what>.png` in `--out=`), then quits.

@export var first_s := 12.0
@export var gap_s := 1.2

var _out := "res://agent/out/rfc022e4/diag"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await get_tree().create_timer(first_s).timeout
	var field := get_tree().get_first_node_in_group("grass_field")
	var terrain := Terrain.of(self)
	if field == null:
		get_tree().quit()
		return
	var mat: ShaderMaterial = field.get("_material")
	var ground: ShaderMaterial = terrain.get("material_override")
	var steps := [
		["base", func(): pass],
		["wavesoff", func(): ground.set_shader_parameter("grass_wave_strength", 0.0)],
		["gustoff", func(): mat.set_shader_parameter("gust_lighten", 0.0)],
		["clumpsoff", func(): mat.set_shader_parameter("use_clumps", false)],
		["paintoff", func(): ground.set_shader_parameter("grass_paint_amount", 0.0)],
	]
	var i := 0
	for step in steps:
		step[1].call()
		await get_tree().create_timer(gap_s).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(_out.path_join("diag_%02d_%s.png" % [i, step[0]])))
		i += 1
	print("RFC022E4_DIAG done")
	get_tree().quit()
