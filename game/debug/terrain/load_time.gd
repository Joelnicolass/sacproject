extends Node

## How long a map takes to load, its ground included: for each map asked it loads map.tscn (its resources again every
## run), instances it, puts it in the tree, waits two frames, and prints one line per run,
## `LOAD TIME <tag> run=<n> load=<ms> instance=<ms> ready=<ms> total=<ms>`, then quits. It names no class of the ground,
## so the same two files (this and load_time.tscn) measure before and after a cut: copy them into the other checkout.
## With a window the ground mesh is built; headless measures what the dedicated server does. `--log=terrain_load` adds
## the parts of the ground (faces + index, mesh). Plan 063D S3 criterion 2: <= the time before the cut + 200 ms.
## "$GODOT" --path game res://debug/terrain/load_time.tscn -- [--map=high_noon,winter_wonder] [--runs=3]

const MAPS_DIR := "res://scenes/map/maps/"

var _maps := PackedStringArray(["high_noon", "winter_wonder"])
var _runs := 3


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			_maps = argument.substr(6).split(",", false)
		elif argument.begins_with("--runs="):
			_runs = maxi(1, int(argument.substr(7)))
	for tag in _maps:
		for run in _runs:
			await _measure(tag, run + 1)
	get_tree().quit(0)


func _measure(tag: String, run: int) -> void:
	var path := MAPS_DIR + tag + "/map.tscn"
	var started := Time.get_ticks_usec()
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var loaded := Time.get_ticks_usec()
	if packed == null:
		print("LOAD TIME %s FAIL: no %s" % [tag, path])
		return
	var map := packed.instantiate()
	var instanced := Time.get_ticks_usec()
	add_child(map)
	var entered := Time.get_ticks_usec()
	await get_tree().process_frame
	await get_tree().process_frame
	print("LOAD TIME %s run=%d load=%.0f instance=%.0f ready=%.0f total=%.0f" % [tag, run, (loaded - started) / 1000.0,
			(instanced - loaded) / 1000.0, (entered - instanced) / 1000.0, (entered - started) / 1000.0])
	map.queue_free()
	await get_tree().process_frame
