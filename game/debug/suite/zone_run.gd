extends Node3D

const ZONE_CASES := preload("res://debug/suite/zone_cases.gd")
const RIFT_CASES := preload("res://debug/suite/rift_cases.gd")
const AURA_CASES := preload("res://debug/suite/aura_cases.gd")

## Runs only the zone cases (debug/suite/zone_cases.gd, rift_cases.gd, aura_cases.gd) and quits: the loop of whoever works on the zones,
## instead of the whole rules_suite. `godot --headless --path game --fixed-fps 600 res://debug/suite/zone_run.tscn` (after `--`, `--only=zone`,
## `--only=rift` or `--only=aura` runs one file).


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var results := {}
	if only.is_empty() or only == "zone":
		results.merge(await ZONE_CASES.new().run(self))
	if only.is_empty() or only == "rift":
		results.merge(await RIFT_CASES.new().run(self))
	if only.is_empty() or only == "aura":
		results.merge(await AURA_CASES.new().run(self))
	var failed := 0
	for name in results:
		var ok := bool((results[name] as Dictionary).get("ok", false))
		failed += 0 if ok else 1
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
	print("ZONE CASES %s" % ("PASS" if failed == 0 else "FAIL (%d)" % failed))
	get_tree().quit(0 if failed == 0 else 1)
