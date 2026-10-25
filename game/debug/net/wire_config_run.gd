extends Node

## 055s: runs only the WIRE CONFIG case and quits, so the hash can be taken on any commit by copying wire_config_cases.gd,
## this script and wire_config_run.tscn:  godot --headless --path game res://debug/net/wire_config_run.tscn
## Exit code 1 when the case fails.

const CASES := preload("res://debug/net/wire_config_cases.gd")


func _ready() -> void:
	var results: Dictionary = CASES.new().run(self)
	var ok := true
	for name: String in results:
		ok = ok and bool((results[name] as Dictionary).get("ok", false))
	get_tree().quit(0 if ok else 1)
