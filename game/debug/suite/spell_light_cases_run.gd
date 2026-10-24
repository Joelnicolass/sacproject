extends Node3D

## Runs only the light-pass cases (spell_light_cases.gd) and prints PASS or FAIL per case, without the whole rules suite:
##   godot --headless --fixed-fps 600 --path . res://debug/suite/spell_light_cases.tscn

const LIGHT_CASES := preload("res://debug/suite/spell_light_cases.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = LIGHT_CASES.new().run(self)
	var failures := 0
	print("== Spell light cases ==")
	for name in results:
		var ok := bool((results[name] as Dictionary).get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % results[name])
	print("SPELL LIGHT CASES PASS" if failures == 0 else "SPELL LIGHT CASES FAIL (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
