extends SceneTree

## Runs GrassKit's own tests, headless, no game:
##   godot --headless --path <project> --script res://addons/grass_kit/tests/grass_test_runner.gd
## Every `test_*.gd` file next to this one; every method of it named `test_*`. Prints one line per
## method and GRASSKIT TESTS PASS (exit 0) or GRASSKIT TESTS FAIL: n (exit 1). `-- --only=<file>` runs one
## file. Add a test: a new `func test_x()` or a new file.

const DIR := "res://addons/grass_kit/tests"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var fails := 0
	var count := 0
	for file in DirAccess.get_files_at(DIR):
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		if not only.is_empty() and file.get_basename() != only:
			continue
		var script := load(DIR.path_join(file)) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s does not load" % file)
			fails += 1
			continue
		for info in script.get_script_method_list():
			var method: String = info["name"]
			if not method.begins_with("test_"):
				continue
			var suite: Object = script.new()
			suite.tree = self
			var holder := Node.new()
			holder.name = "Test"
			root.add_child(holder)
			suite.root = holder
			await suite.call(method)
			count += 1
			var ok: bool = suite.fails == 0
			print("%s %s::%s (%d checks)" % ["PASS" if ok else "FAIL", file.get_basename(), method, suite.passes + suite.fails])
			if not ok:
				fails += 1
			holder.queue_free()
			await process_frame
	if fails == 0:
		print("GRASSKIT TESTS PASS (%d)" % count)
		quit(0)
	else:
		print("GRASSKIT TESTS FAIL: %d of %d" % [fails, count])
		quit(1)
