extends Node

## RFC-050: where the wizards would stand on a map. For every PlayerStart of the active map (`--map=<tag>` after `--`):
## the slot is one of 1..player_starts and unique, the spot `spawn_transform()` gives is on the land, and all
## the spots lie in one walkable region of the navmesh (the seats can meet). Prints STARTS PASS / STARTS FAIL; exit 0 / 1.
## "$GODOT" --headless --path game res://tools/audit/check_map_starts.tscn -- --map=peaks
## It enters the map scene as the bake does (autoloads exist); it does not run the match.

## A spot this far from a walkable polygon counts as outside the navmesh.
const SNAP_M := 6.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := MapCatalog.active()
	var packed := map.map_scene
	var root: MapRoot = packed.instantiate() as MapRoot if packed else null
	if root == null or root.terrain == null or root.starts == null:
		_finish(["the scene of '%s' is not a MapRoot with ground and starts" % map.tag])
		return
	add_child(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var problems: Array[String] = []
	var regions := NavRegions.new()
	var navmesh := root.nav_region.navigation_mesh if root.nav_region != null else null
	if navmesh == null or navmesh.get_polygon_count() == 0:
		problems.append("the map has no navmesh")
	else:
		regions.build(navmesh)
	var starts: Array[PlayerStart] = []
	for node in root.starts.get_children():
		if node is PlayerStart:
			starts.append(node)
	if starts.size() != map.player_starts:
		problems.append("%d PlayerStart nodes, the definition says %d seats" % [starts.size(), map.player_starts])
	var seen := {}
	var shared_region := -2
	for start in starts:
		if start.slot < 1 or start.slot > map.player_starts or seen.has(start.slot):
			problems.append("%s: slot %d is out of range or repeated" % [start.name, start.slot])
		seen[start.slot] = true
		var spot := start.spawn_transform().origin
		var on_ground := root.terrain.is_on_ground(spot.x, spot.z)
		var region := regions.component_at(spot, SNAP_M) if regions.polygon_count > 0 else -1
		var region_size := regions.component_size_at(spot, SNAP_M) if regions.polygon_count > 0 else 0
		print("start %s slot %d: altar (%.0f, %.0f) wizard (%.0f, %.0f) ground %s, region %d of %d polygons" % [
			start.name, start.slot, start.global_position.x, start.global_position.z, spot.x, spot.z, on_ground, region, region_size])
		if not on_ground:
			problems.append("%s: the wizard spot is off the land" % start.name)
		if region < 0:
			problems.append("%s: the wizard spot is not on the navmesh" % start.name)
		elif shared_region == -2:
			shared_region = region
		elif region != shared_region:
			problems.append("%s: the wizard spot is in another walkable region than the first seat" % start.name)
	root.queue_free()
	_finish(problems)


func _finish(problems: Array[String]) -> void:
	for problem in problems:
		print("check_map_starts: FAIL %s" % problem)
	if problems.is_empty():
		print("check_map_starts: STARTS PASS (%s)" % MapCatalog.active().tag)
	get_tree().quit(0 if problems.is_empty() else 1)
