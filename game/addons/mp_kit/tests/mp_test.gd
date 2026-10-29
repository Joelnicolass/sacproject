extends RefCounted

## Base of every kit test file: `check(cond, what)` records one result. The runner calls each `test_*` method.

var fails: int = 0
var passes: int = 0
var tree: SceneTree


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		fails += 1
		print("  FAIL %s" % what)
