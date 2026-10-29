extends "res://addons/prop_kit/tests/prop_test.gd"

## The command-line tools, each run as its own headless Godot (as scenes, the way the game runs):
## scatter_scene saves a scattered scene; bake_scene --check gives the same hash twice and says when
## there is no saved bake; an autoload the scene's scripts use is there.


func _run(tool_scene: String, args: PackedStringArray) -> Array:
	var all := PackedStringArray(
		["--headless", "--path", ProjectSettings.globalize_path("res://"), tool_scene, "--"]
	)
	all.append_array(args)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), all, output, true)
	return [code, "\n".join(PackedStringArray(output))]


func test_scatter_scene_saves_the_props() -> void:
	var out := "user://prop_kit_tool_scatter.tscn"
	var run := _run(
		"res://addons/prop_kit/tools/scatter_scene.tscn",
		["--scene=res://addons/prop_kit/examples/grove_2d/grove_2d.tscn", "--out=" + out]
	)
	check(run[0] == 0, "it ends well (%s)" % run[1].right(200))
	var scene := (load(out) as PackedScene).instantiate()
	check(scene.get_node("World/Grove").get_child_count() > 100, "the props are in the saved scene")
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(out))


func test_bake_scene_check_is_reproducible() -> void:
	var args := PackedStringArray(
		["--scene=res://addons/prop_kit/examples/grove_2d/grove_2d.tscn", "--check"]
	)
	var first := _run("res://addons/prop_kit/tools/bake_scene.tscn", args)
	var second := _run("res://addons/prop_kit/tools/bake_scene.tscn", args)
	var hash_of := func(text: String) -> String:
		var found := RegEx.create_from_string("bake_scene: Nav (\\d+)").search(text)
		return found.get_string(1) if found != null else ""
	check(hash_of.call(first[1]) != "", "it prints a hash (%s)" % first[1].right(200))
	check(hash_of.call(first[1]) == hash_of.call(second[1]), "the same hash twice")
	check(first[0] == 1 and first[1].contains("differs from saved"), "no saved bake: exit 1")


func test_bake_scene_runs_the_project_autoloads() -> void:
	if not ProjectSettings.has_setting("autoload/PropLabGlobals"):
		check(true, "only in propkit_lab, which has the autoload")
		return
	var run := _run(
		"res://addons/prop_kit/tools/bake_scene.tscn",
		["--scene=res://tool_check/uses_autoload.tscn", "--check"]
	)
	check(not run[1].contains("SCRIPT ERROR"), "the map's script finds its autoload (%s)" % run[1].right(300))
	var found := RegEx.create_from_string("bake_scene: Nav \\d+ .*zones 4/4").search(run[1])
	check(found != null, "it bakes the 20 m floor the autoload sized (%s)" % run[1].right(300))
