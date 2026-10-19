extends Node3D

## RFC-049 049b (F291): runs the team cases alone (F6, or headless with --quit-after). rules_suite runs the same cases inside its own run.

const TEAM_CASES := preload("res://debug/match/team_cases.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Dictionary = await TEAM_CASES.new().run(self)
	var failures := 0
	for name in results.keys():
		var ok := bool(results[name].get("ok", false))
		print("%s: %s" % [name, "PASS" if ok else "FAIL"])
		if not ok:
			failures += 1
			print("  %s" % results[name])
	print("TEAM CASES PASS" if failures == 0 else "TEAM CASES FAIL (%d)" % failures)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if failures == 0 else 1)
