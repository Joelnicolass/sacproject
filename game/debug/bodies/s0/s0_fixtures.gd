extends SceneTree
## 055s s0 (disposable): writes the fixtures of the placeholder probe into tmp/ (a body scene whose Look is an
## InstancePlaceholder, the same scene without it, and the look: a mesh, a sound and a scene that holds both).
## Runs alone in its own process so the resource cache is clean when s0_placeholder.gd reads them.
## Prints `S0 fixtures ...` and always ends in quit().

const DIR := "res://debug/bodies/s0/tmp/"


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 VERDICT fixtures TIMEOUT")
		quit(2))
	quit(_main())


func _main() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var ig := FileAccess.open(DIR + ".gdignore", FileAccess.WRITE)
	if ig != null:
		ig.close()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(400000)
	wav.data = pcm
	if not _save(wav, DIR + "look_sound.res"):
		return 1
	var mesh := BoxMesh.new()
	if not _save(mesh, DIR + "look_mesh.res"):
		return 1
	var look := Node3D.new()
	look.name = "Look"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	look.add_child(mi)
	mi.owner = look
	var snd := AudioStreamPlayer3D.new()
	snd.name = "Sound"
	snd.stream = wav
	look.add_child(snd)
	snd.owner = look
	if not _save_scene(look, DIR + "look.tscn"):
		return 1
	var look_scene := load(DIR + "look.tscn") as PackedScene
	for placeholder: bool in [true, false]:
		var body := Node3D.new()
		body.name = "Body"
		var muzzle := Marker3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0.0, 1.2, 0.8)
		body.add_child(muzzle)
		muzzle.owner = body
		var inst := look_scene.instantiate() as Node3D
		inst.name = "Look"
		body.add_child(inst)
		inst.owner = body
		if placeholder:
			inst.set_scene_instance_load_placeholder(true)
		var out := DIR + ("body_placeholder.tscn" if placeholder else "body_plain.tscn")
		if not _save_scene(body, out):
			return 1
		var text := FileAccess.get_file_as_string(out)
		print("S0 fixtures %s written, mentions look.tscn=%s, instance_placeholder attr=%s" % [out.get_file(), text.contains("look.tscn"), text.contains("instance_placeholder")])
		for line: String in text.split("\n"):
			if line.begins_with("[node") or line.begins_with("[ext_resource"):
				print("S0 fixtures   | %s" % line)
		body.free()
	print("S0 fixtures DONE")
	return 0


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		print("S0 fixtures ERROR saving %s: %d" % [path, err])
		return false
	res.take_over_path(path)
	return true


func _save_scene(root_node: Node, path: String) -> bool:
	var ps := PackedScene.new()
	var err := ps.pack(root_node)
	if err != OK:
		print("S0 fixtures ERROR packing %s: %d" % [path, err])
		return false
	return _save(ps, path)
