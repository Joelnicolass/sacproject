extends SceneTree

## Runs FsmKit's own tests, headless, no game:
##   godot --headless --path <project> --script res://addons/fsm_kit/tests/fsm_test_runner.gd
## Every `test_*.gd` file next to this one; every method of it named `test_*`. Prints one line per method and
## FSMKIT TESTS PASS (exit 0) or FSMKIT TESTS FAIL: n (exit 1). Add a test: a new `func test_x()` or a new file.

const DIR := "res://addons/fsm_kit/tests"


func _initialize() -> void:
	await process_frame
	var fails := 0
	var count := 0
	for file in DirAccess.get_files_at(DIR):
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script := load(DIR.path_join(file)) as GDScript
		for info in script.get_script_method_list():
			var method: String = info["name"]
			if not method.begins_with("test_"):
				continue
			var suite: Object = script.new()
			suite.tree = self
			await suite.call(method)
			count += 1
			var ok: bool = suite.fails == 0
			print("%s %s::%s (%d checks)" % ["PASS" if ok else "FAIL", file.get_basename(), method, suite.passes + suite.fails])
			if not ok:
				fails += 1
	if fails == 0:
		print("FSMKIT TESTS PASS (%d)" % count)
	else:
		print("FSMKIT TESTS FAIL: %d of %d" % [fails, count])
	quit(0 if fails == 0 else 1)
