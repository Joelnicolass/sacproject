extends RefCounted

## Base of every PropKit test file: `check(cond, what)` records one result; `near(a, b)` compares
## floats and vectors. The runner calls each `test_*` method with `tree` set and frees `root` after.

var fails: int = 0
var passes: int = 0
var tree: SceneTree
## A node the test builds its scene under (added to the tree by the runner, freed after).
var root: Node


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		fails += 1
		print("  FAIL %s" % what)


func near(a: Variant, b: Variant, epsilon := 0.0001) -> bool:
	if a is float or a is int:
		return absf(float(a) - float(b)) <= epsilon
	if a is Vector2 or a is Vector3:
		return a.is_equal_approx(b) or (a - b).length() <= epsilon
	return a == b


## Waits for `frames` physics frames (colliders added to the tree are in the space after one).
func physics(frames := 2) -> void:
	for i in frames:
		await tree.physics_frame
