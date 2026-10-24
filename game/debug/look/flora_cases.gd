extends Node

## RFC-054 (F380-F387): runner of the headless flora cases. 054a: flora_placement_cases.gd (the density images of the
## maps and FloraPlacement); 054b: cell_ring_cases.gd (CellRing against the golden of GrassField's old ring); 054c:
## flora_field_cases.gd (FloraField and MeshPlanter; `-- --dedicated --no-flow` runs its map case as the dedicated server: without
## --no-flow MpFlow would replace this scene with the world).
## A case script may declare `var tree: SceneTree` (the runner sets it) and make `run` a coroutine.
##   godot --headless --path game --quit-after 60000 res://debug/look/flora_cases.tscn
## Prints `<case>: PASS|FAIL` and `FLORA CASES PASS|FAIL (n)`; headless quits with 0 / 1.
## Watchdog: past `timeout_s` of wall time it prints `FLORA CASES FAIL timeout` and quits 1. The case scripts are loaded
## at run time (not preloaded), so one that fails to compile ends in a FAIL line instead of a runner without a script.

const CASES := ["res://debug/look/flora_placement_cases.gd", "res://debug/look/cell_ring_cases.gd", "res://debug/look/flora_field_cases.gd", "res://debug/look/flora_variation_cases.gd"]

## Real seconds (not game time: --fixed-fps would stretch a game-time timer).
@export var timeout_s := 40.0

var _done := false


func _ready() -> void:
	_watchdog()
	_run.call_deferred()


func _watchdog() -> void:
	var limit := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while not _done:
		await get_tree().process_frame
		if Time.get_ticks_msec() > limit and not _done:
			_done = true
			print("FLORA CASES FAIL timeout")
			get_tree().quit(1)


func _run() -> void:
	var started := Time.get_ticks_msec()
	var results := {}
	for path: String in CASES:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			results[path.get_file().get_basename()] = {"ok": false, "reason": "no compila"}
			continue
		var instance: Object = script.new()
		if "tree" in instance:
			instance.set("tree", get_tree())
		var result: Dictionary = await instance.call("run")
		results.merge(result)
		# A frame between scripts so the watchdog can speak.
		await get_tree().process_frame
		if _done:
			return
	_done = true
	var failures := 0
	print("== Flora cases (%d ms) ==" % (Time.get_ticks_msec() - started))
	for name in results:
		var item: Dictionary = results[name]
		var ok := bool(item.get("ok", false))
		print("%s: %s  %s" % [name, "PASS" if ok else "FAIL", item])
		if not ok:
			failures += 1
	print("FLORA CASES PASS" if failures == 0 else "FLORA CASES FAIL (%d)" % failures)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures == 0 else 1)
