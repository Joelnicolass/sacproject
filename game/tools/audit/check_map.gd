extends Node

## Whether a map can be played as it is saved: its seats (MapSeatChecks), what stands on land and the level bases
## (MapGroundChecks), and that every altar can walk to every manafount (MapPathChecks). With `--map=<tag>` after `--` it checks
## that map, else every map of the catalog. Prints the problems and one `CHECK MAP <tag> PASS` / `CHECK MAP <tag> FAIL` per map;
## exit 0 when all pass, 1 otherwise. It enters each map scene as the bake does (autoloads exist) and does not run the match.
## Not: fixing anything (the bases are flattened in the editor, the navmesh is baked by MapNavRegion).
## "$GODOT" --headless --path game res://tools/audit/check_map.tscn -- --map=peaks

const MapSeatChecks := preload("res://tools/audit/map_seat_checks.gd")
const MapGroundChecks := preload("res://tools/audit/map_ground_checks.gd")
const MapPathChecks := preload("res://tools/audit/map_path_checks.gd")


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
	ActiveMatch.choose_ids(tag, ActiveMatch.mode_tag())
	var packed := definition.map_scene
	var root: MapRoot = packed.instantiate() as MapRoot if packed != null else null
	if root == null or root.starts == null:
		return ["the scene is not a MapRoot with starts"]
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var problems: Array[String] = []
	var navmesh := root.nav_region.navigation_mesh if root.nav_region != null else null
	var regions := NavRegions.new()
	if navmesh == null or navmesh.get_polygon_count() == 0:
		problems.append("the map has no navmesh")
		navmesh = null
	else:
		regions.build(navmesh)
	var terrain := Terrain.of(root)
	if terrain == null or not terrain.is_loaded():
		problems.append("the map has no loaded Terrain")
	else:
		problems.append_array(MapSeatChecks.check(root, definition, terrain, regions))
		problems.append_array(MapGroundChecks.check(root, terrain))
	if navmesh != null:
		problems.append_array(await MapPathChecks.check(root, navmesh, regions))
	root.queue_free()
	await get_tree().process_frame
	return problems
