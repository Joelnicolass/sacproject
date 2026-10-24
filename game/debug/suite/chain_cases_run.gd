extends Node3D

## Runs only the 061e cases (chain_cases.gd) and prints PASS or FAIL per case, to check the jumping spells without the whole rules suite:
##   godot --headless --fixed-fps 600 --path . res://debug/suite/chain_cases.tscn

const CHAIN_CASES := preload("res://debug/suite/chain_cases.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = await CHAIN_CASES.new().run(self)
	var failures := 0
	print("== Chain cases ==")
	for name in results:
		var ok := bool((results[name] as Dictionary).get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % results[name])
	print("CHAIN CASES PASS" if failures == 0 else "CHAIN CASES FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
