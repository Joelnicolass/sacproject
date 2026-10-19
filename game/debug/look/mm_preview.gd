extends Node3D
## Spike Material Maker: dos planos con sol rasante, izquierda = MM, derecha = CC0 (comparación).
## F6 para verlo; con --capture=<ruta.png> guarda captura y sale.
@export_dir var mm_dir := "res://assets/mm/persephone_grass"
@export var uv_repeat := 6.0
@export var capture_delay_frames := 20

func _mat(albedo: String, normal: String, orm: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(albedo))
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(Image.load_from_file(normal))
	var o := ImageTexture.create_from_image(Image.load_from_file(orm))
	m.ao_enabled = true
	m.ao_texture = o; m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = o; m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.uv1_scale = Vector3(uv_repeat, uv_repeat, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _ready() -> void:
	var cc := "res://assets/cc0/ground/Grass004/"
	var mats := [
		_mat(mm_dir + "/albedo.png", mm_dir + "/normal.png", mm_dir + "/orm.png"),
		_mat(cc + "albedo.jpg", cc + "normal.png", cc + "orm.png"),
	]
	for i in 2:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(10, 24)
		mi.mesh = pm; mi.material_override = mats[i]
		mi.position = Vector3(-5.2 + i * 10.4, 0, -8)
		add_child(mi)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, 35, 0); sun.light_energy = 2.0
	sun.light_color = Color(1.0, 0.82, 0.6); sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.45, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.35, 0.4, 0.5); env.environment.ambient_light_energy = 0.6
	add_child(env)
	var cam := Camera3D.new(); cam.position = Vector3(0, 1.3, 3); cam.rotation_degrees = Vector3(-14, 0, 0)
	cam.fov = 60; add_child(cam)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): _capture(a.substr(10))

func _capture(path: String) -> void:
	for i in capture_delay_frames: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
