@tool
extends RefCounted

## Editor only (loaded when used, never in a game): «Bake» on a zones node and Project > Tools >
## "PropKit: Bake the open scene" save the open scene and bake it the way the game will, in a
## separate headless Godot with the project's autoloads (tools/bake_scene.tscn), then reload it.
## Where the scene sits in the editor plays no part.

const TOOL_SCENE := "res://addons/prop_kit/tools/bake_scene.tscn"


## Saves the open scene, bakes every zones node in it, and reloads it with the new bakes.
static func bake_open_scene() -> void:
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path.is_empty():
		push_error("PropKit: save the scene first; the bake goes next to it")
		return
	var path := scene.scene_file_path
	var bakes: Array[String] = []
	for node in scene.find_children("*", "", true, false):
		if node is PropNavZones3D or node is PropNavZones2D:
			var saved: PropNavBake = node.get(&"saved")
			if saved != null and not saved.resource_path.is_empty():
				bakes.append(saved.resource_path)
	EditorInterface.save_scene()
	var args := PackedStringArray(
		[
			"--headless", "--path", ProjectSettings.globalize_path("res://"), TOOL_SCENE, "--",
			"--scene=" + path,
		]
	)
	print("PropKit: baking %s…" % path)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text := "\n".join(PackedStringArray(output))
	for line in text.split("\n"):
		if line.begins_with("bake_scene:"):
			print("PropKit: " + line.trim_prefix("bake_scene: "))
	if code != 0:
		printerr(text)
		push_error("PropKit: the bake of %s failed (exit code %d), see above" % [path, code])
		return
	# The saved bakes it wrote over, then the scene (it may point at a new one).
	for bake in bakes:
		ResourceLoader.load(bake, "", ResourceLoader.CACHE_MODE_REPLACE)
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.reload_scene_from_path(path)
