extends SceneTree

## Bakes the navmesh zones of a scene from the command line, for CI or a build step:
##   godot --headless --path <project> --script res://addons/prop_kit/tools/bake_scene.gd \
##     -- --scene=res://maps/forest.tscn [--check]
## Every PropNavZones3D / PropNavZones2D of the scene bakes all its zones from scratch (its saved
## bake is ignored), the way «Bake» does in the editor. The scene's own scripts run, as in a game.
## Without --check: each result is saved over the node's `saved` (or next to the scene as
## <scene>_nav.res, <scene>_<node>_nav.res for a second node). When a node gets a new `saved`, the
## scene file is updated from a fresh copy of it, so nothing the scripts did while baking is kept.
## With --check nothing is written: it prints each bake's content hash (two runs must print the
## same) and whether it matches the saved one. Exit code: 0 done, 1 an error or (with --check) a
## bake that differs from its saved one.

const TIMEOUT_FRAMES := 6000


func _initialize() -> void:
	var path := ""
	var check := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			path = arg.trim_prefix("--scene=")
		elif arg == "--check":
			check = true
	if path.is_empty():
		printerr("bake_scene: pass -- --scene=res://path/to/scene.tscn [--check]")
		quit(1)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("bake_scene: cannot load %s" % path)
		quit(1)
		return
	var scene := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var nodes: Array[Node] = []
	var was_saved: Array[PropNavBake] = []
	for node in scene.find_children("*", "", true, false):
		if node is PropNavZones3D or node is PropNavZones2D:
			nodes.append(node)
			was_saved.append(node.get(&"saved"))
			# No saved bake: the node bakes every zone when it starts.
			node.set(&"saved", null)
	if nodes.is_empty():
		printerr("bake_scene: no PropNavZones3D / PropNavZones2D in %s" % path)
		quit(1)
		return
	root.add_child(scene)
	var failed := false
	# Node path -> the new saved bake, for the nodes that had none.
	var new_saved: Dictionary[NodePath, PropNavBake] = {}
	for i in nodes.size():
		var node := nodes[i]
		if not await _settle(node):
			printerr("bake_scene: %s did not finish baking" % node.name)
			failed = true
			continue
		var baked: PropNavBake = node.call(&"to_saved")
		var old := was_saved[i]
		var stats: PropNavStats = node.get(&"stats")
		if check:
			var same := old != null and old.content_hash() == baked.content_hash()
			var verdict := "matches saved" if same else "differs from saved"
			print("bake_scene: %s %d %s (%s)" % [node.name, baked.content_hash(), verdict, stats])
			failed = failed or not same
			continue
		var out := old.resource_path if old != null and not old.resource_path.contains("::") else ""
		var fresh_file := out.is_empty()
		if fresh_file:
			var suffix := "" if i == 0 else "_" + String(node.name).to_snake_case()
			out = path.get_basename() + suffix + "_nav.res"
		if node.call(&"save_bake", out) != OK:
			failed = true
			continue
		if fresh_file:
			new_saved[scene.get_path_to(node)] = node.get(&"saved")
		print("bake_scene: %s saved %s (%s)" % [node.name, out, stats])
	if not new_saved.is_empty() and not failed:
		failed = not _point_scene_at(packed, path, new_saved)
	quit(1 if failed else 0)


## Saves the scene at `path` with each node of `bakes` pointing at its new saved bake. Works on a
## fresh copy that never enters the tree, so no script runs on it.
func _point_scene_at(
	packed: PackedScene, path: String, bakes: Dictionary[NodePath, PropNavBake]
) -> bool:
	var fresh := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for node_path in bakes:
		fresh.get_node(node_path).set(&"saved", bakes[node_path])
	var repacked := PackedScene.new()
	var err := repacked.pack(fresh)
	fresh.free()
	if err == OK:
		err = ResourceSaver.save(repacked, path)
	if err != OK:
		printerr("bake_scene: cannot save %s (%s)" % [path, error_string(err)])
		return false
	return true


## Waits until `node` has baked and applied every zone (a MANUAL node is applied here) and nothing
## runs any more.
func _settle(node: Node) -> bool:
	var applied := [false]
	var on_applied := func(_zones: PackedInt32Array) -> void: applied[0] = true
	node.connect(&"applied", on_applied)
	var ok := false
	for frame in TIMEOUT_FRAMES:
		await process_frame
		if node.call(&"has_result"):
			node.call(&"apply")
		if applied[0] and node.call(&"is_done") and not node.call(&"has_result"):
			ok = true
			break
	node.disconnect(&"applied", on_applied)
	return ok
