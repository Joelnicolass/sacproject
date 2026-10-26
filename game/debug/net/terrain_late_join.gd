extends Node3D

## Net case of the deformable ground, alone: a server's Terrain and two clients' Net (one early, one that joins late with the
## snapshot) in this one process, and the checksum of their ground compared (debug/suite/terrain_cases.gd `_net`). Prints
## TERRAIN NET PASS. `godot --headless --fixed-fps 600 --path game res://debug/net/terrain_late_join.tscn`.

const CASES := preload("res://debug/suite/terrain_cases.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = await CASES.new().run_net(self)
	var ok := bool((results["terrain_net"] as Dictionary).get("ok", false))
	print("TERRAIN NET %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
