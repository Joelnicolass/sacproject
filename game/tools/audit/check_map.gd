extends Node

## Whether the maps of the catalog can be played as they are saved (MapChecks: the seats, what
## stands on land, the level bases, every altar walking to every manafount). With `--map=<tag>`
## after `--` it checks that map, else every map of the catalog. Prints the problems and one `CHECK
## MAP <tag> PASS` / `CHECK MAP <tag> FAIL` per map; exit 0 when all pass, 1 otherwise. It enters
## each map scene as the bake does (autoloads exist) and does not run the match.
## Not: fixing anything (the bases are flattened in the editor, the navmesh is baked by
## MapNavRegion). "$GODOT" --headless --path game res://tools/audit/check_map.tscn -- --map=peaks

const MapChecks := preload("res://tools/audit/map_checks.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed := 0
	for tag in _tags():
		var problems: Array[String] = await _check(StringName(tag))
		for problem in problems:
			print("check_map: %s: %s" % [tag, problem])
		print("CHECK MAP %s %s" % [tag, "PASS" if problems.is_empty() else "FAIL"])
		if not problems.is_empty():
			failed += 1
	get_tree().quit(0 if failed == 0 else 1)


## The tag of `--map=<tag>`, else every map of the catalog (the test maps too).
func _tags() -> PackedStringArray:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map="):
			return PackedStringArray([argument.substr("--map=".length())])
	return MapCatalog.shared().all_tags()


func _check(tag: StringName) -> Array[String]:
	var definition := MapCatalog.shared().find(tag)
	if definition == null:
		return ["no map definition maps/%s/%s.tres" % [tag, tag]]
	var packed := definition.map_scene
	var root: MapRoot = packed.instantiate() as MapRoot if packed != null else null
	if root == null:
		return ["the scene is not a MapRoot"]
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var problems: Array[String] = await MapChecks.check(root, definition)
	root.queue_free()
	await get_tree().process_frame
	return problems
