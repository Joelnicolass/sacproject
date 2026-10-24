extends Node3D

## Runs only the 061i cases (level8_cases.gd) and prints PASS or FAIL per case, to check the level-8 spells without the whole rules suite:
##   godot --headless --fixed-fps 600 --path . res://debug/suite/level8_cases.tscn

const LEVEL8_CASES := preload("res://debug/suite/level8_cases.gd")


## The run is cut after 10 real minutes (the machine queue kills a Godot after 12).
const WATCHDOG_S := 600.0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("LEVEL 8 CASES TIMEOUT")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = await LEVEL8_CASES.new().run(self)
	var failures := 0
	print("== Level 8 cases ==")
	for name in results:
		var ok := bool((results[name] as Dictionary).get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % results[name])
	print("LEVEL 8 CASES PASS" if failures == 0 else "LEVEL 8 CASES FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
