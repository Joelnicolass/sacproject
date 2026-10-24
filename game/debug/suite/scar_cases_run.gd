extends Node3D

## Runs only the 061k-5 cases (scar_cases.gd) and prints PASS or FAIL per case, to check the marks on the ground without the whole rules suite:
##   godot --headless --path . res://debug/suite/scar_cases.tscn

const SCAR_CASES := preload("res://debug/suite/scar_cases.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = SCAR_CASES.new().run(self)
	var failures := 0
	print("== Scar cases ==")
	for name in results:
		var ok := bool((results[name] as Dictionary).get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % results[name])
	print("SCAR CASES PASS" if failures == 0 else "SCAR CASES FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
