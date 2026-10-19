extends SceneTree

## Playtest harness (RFC-019c): three manafounts side by side (free, Manalith of slot 1, Manalith of
## slot 2), run with a window; saves PNGs of the viewport. Args after `--`: out_dir.
## Run: Godot --path game --script res://agent/harness/fount_fx_shot.gd -- /abs/out

func _initialize() -> void:
	var out_dir := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.6, 0.8)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment.glow_enabled = true
	world.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 200)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.35, 0.2)
	ground.material_override = mat
	world.add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)
	var scene: PackedScene = load("res://scenes/map/props/manafount.tscn")
	var founts: Array[Node3D] = []
	for i in 3:
		var fount: Node3D = scene.instantiate()
		fount.position = Vector3((i - 1) * 40.0, 0, 0)
		world.add_child(fount)
		founts.append(fount)
	for i in [1, 2]:
		var occupant := Node3D.new()
		occupant.name = "Manalith%d" % i
		var script := GDScript.new()
		script.source_code = "extends Node3D\nvar owner_slot := 0\n"
		script.reload()
		occupant.set_script(script)
		occupant.set("owner_slot", i)
		world.add_child(occupant)
		founts[i].occupy(occupant.get_path())
	var cam := Camera3D.new()
	cam.position = Vector3(0, 22, 95)
	cam.fov = 60
	world.add_child(cam)
	cam.look_at(Vector3(0, 20, 0))
	cam.current = true
	await create_timer(4.0).timeout
	root.get_texture().get_image().save_png(out_dir + "/fount_all.png")
	print("saved")
	quit(0)
