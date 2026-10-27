extends Node3D

## Net cases of the deformable ground, alone: a server's Terrain and the Net of clients in this one process (debug/suite/
## terrain_cases.gd `run_net`): `net` (an early client and one that gets the snapshot), and deform_net_cases (a kept change in
## flight before the snapshot, a seat that rejoins 20 s into a Volcano, the Quake's ground on a client). A match is never joined
## half way; the snapshot is for a seat that rejoins. Prints one line per case and TERRAIN NET PASS when all pass.
## `godot --headless --fixed-fps 600 --path game res://debug/net/terrain_late_join.tscn` (`-- --case=<name>` for one).

const CASES := preload("res://debug/suite/terrain_cases.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var results: Dictionary = await CASES.new().run_net(self)
	var ok := not results.is_empty()
	for name: String in results:
		var passed := bool((results[name] as Dictionary).get("ok", false))
		print("%s %s" % [name, "PASS" if passed else "FAIL"])
		ok = ok and passed
	print("TERRAIN NET %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
