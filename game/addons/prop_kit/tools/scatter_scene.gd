extends SceneTree

## Scatters a scene from the command line and saves it, for CI or a build step:
##   godot --headless --path <project> --script res://addons/prop_kit/tools/scatter_scene.gd \
##     -- --scene=res://maps/forest.tscn [--out=res://maps/forest_scattered.tscn]
## Runs every PropScatter3D and PropScatter2D of the scene in tree order (one physics frame after
## loading it, so PropRayGround hits the colliders), then saves it over itself or to `--out`.
## Exit code 0 when saved, 1 on an error.


func _initialize() -> void:
	var path := ""
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if path.is_empty():
		printerr("scatter_scene: pass -- --scene=res://path/to/scene.tscn")
		quit(1)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("scatter_scene: cannot load %s" % path)
		quit(1)
		return
	var scene := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var planted := PropScatterRun.run_all(scene)
	var repacked := PackedScene.new()
	var err := repacked.pack(scene)
	if err == OK:
		err = ResourceSaver.save(repacked, out if not out.is_empty() else path)
	if err != OK:
		printerr("scatter_scene: cannot save (%s)" % error_string(err))
		quit(1)
		return
	print("scatter_scene: %d props planted in %s" % [planted, out if not out.is_empty() else path])
	quit(0)
