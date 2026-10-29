@tool
extends EditorPlugin

## Lab only (run/editor.sh). Does nothing unless MPKIT_EDITOR_CHECK names a scene: then, in the real editor, it
## opens that scene (a 2D world with a bare MpWorld), checks the MpWorld built its pieces, adds a second MpWorld the
## way the Add Child dialog does (add_child + owner) under a 3D node, checks that one too, saves and quits.
## Prints EDITOR PASS / EDITOR FAIL lines and EDITOR CHECK PASS / FAIL.

const PIECES := ["SpawnPoints", "Actors", "Players", "State", "Match", "Hud/Leave"]

var _fails := 0


func _enter_tree() -> void:
	var scene := OS.get_environment("MPKIT_EDITOR_CHECK")
	if not scene.is_empty():
		_run.call_deferred(scene)


func _run(scene_path: String) -> void:
	await _frames(30)
	EditorInterface.open_scene_from_path(scene_path)
	await _frames(30)
	var root := EditorInterface.get_edited_scene_root()
	_check(root != null and root.scene_file_path == scene_path, "the scene opened in the editor")
	if root == null:
		_end()
		return
	var world := root.get_node_or_null("MpWorld")
	_check(world != null, "the scene has its MpWorld")
	if world:
		_check_pieces(world, root, "an MpWorld in an opened 2D scene")
		_check(world.get_node_or_null("SpawnPoints/P1") is Marker2D, "2D markers in a 2D world")
		_check(world.get_node_or_null("State/MpSync") is MultiplayerSynchronizer, "the state got its synchronizer")
	var level := Node3D.new()
	level.name = "Level3D"
	root.add_child(level)
	level.owner = root
	var added: Node = (load("res://addons/mp_kit/nodes/mp_world.gd") as GDScript).new()
	added.name = "Added"
	level.add_child(added)
	added.owner = root
	await _frames(10)
	_check_pieces(added, root, "an MpWorld added like the Add Child dialog does")
	_check(added.get_node_or_null("SpawnPoints/P1") is Marker3D, "3D markers under a 3D node")
	EditorInterface.save_scene()
	await _frames(10)
	## The Setup game wizard, inside the editor (what its Create button runs).
	var folder := "res://scratch/editor_game"
	var dir := ProjectSettings.globalize_path(folder)
	if DirAccess.dir_exists_absolute(dir):
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
	var wizard: Object = (load("res://addons/mp_kit/editor/mp_setup_wizard.gd") as GDScript).new()
	wizard.set("folder", folder)
	_check(int(wizard.call("write")) == OK, "the Setup game wizard writes a game inside the editor")
	EditorInterface.get_resource_filesystem().scan()
	await _frames(30)
	EditorInterface.open_scene_from_path(folder.path_join("world.tscn"))
	await _frames(30)
	var made := EditorInterface.get_edited_scene_root()
	_check(made != null and made.get_node_or_null("MpWorld/Players") != null, "the wizard's world opens in the editor with its MpWorld")
	_end()


func _check_pieces(world: Node, root: Node, what: String) -> void:
	for piece in PIECES:
		var node := world.get_node_or_null(piece)
		_check(node != null and node.owner == root, "%s: %s is built and saved with the scene" % [what, piece])


func _check(ok: bool, what: String) -> void:
	print(("EDITOR PASS " if ok else "EDITOR FAIL ") + what)
	if not ok:
		_fails += 1


func _end() -> void:
	print("EDITOR CHECK %s" % ("PASS" if _fails == 0 else "FAIL"))
	EditorInterface.get_base_control().get_tree().quit(0 if _fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await EditorInterface.get_base_control().get_tree().process_frame
