extends Node

## Saves the ground trimesh of a terrain as a ConcavePolygonShape3D `.res`, the shape of the `Collision` body a map without a
## terrain.glb keeps under its Terrain (the glb of the original maps brings its own at import).
## "$GODOT" --headless --path game res://tools/bake/bake_terrain_collision.tscn -- --terrain=res://.../terrain.res --out=res://.../terrain_collision.res
## It builds the Terrain from the data as the game does (Mesh.create_trimesh_shape), so the shape is the one the sim stood on.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var terrain_path := ""
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--terrain="):
			terrain_path = argument.substr(10)
		elif argument.begins_with("--out="):
			out = argument.substr(6)
	var data := load(terrain_path) as MapTerrainData if not terrain_path.is_empty() else null
	if data == null or out.is_empty():
		push_error("bake_terrain_collision: needs --terrain=<MapTerrainData .res> and --out=<.res>.")
		get_tree().quit(1)
		return
	var terrain := Terrain.new()
	terrain.shape = TerrainShape.with_data(data)
	terrain.add_child(terrain.shape)
	add_child(terrain)
	await get_tree().process_frame
	var ground := terrain.ground_shape()
	if ground == null or ResourceSaver.save(ground, out) != OK:
		push_error("bake_terrain_collision: could not build or save %s." % out)
		get_tree().quit(1)
		return
	print("bake_terrain_collision: written %s (%d faces)" % [out, ground.get_faces().size() / 3])
	get_tree().quit(0)
