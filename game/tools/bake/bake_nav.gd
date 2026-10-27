extends Node

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## Bakes the map's navmesh headless (RFC-035 035f): the static colliders of the `nav_source` nodes of the map scene (the
## terrain's collision, the buildings, the manafounts) with the numbers of data/nav/nav_bake.tres, into scenes/map/maps/<tag>/nav.res
## (the navmesh of the map's NavRegion; the «Hornear navmesh» button of the map's NavRegion runs this). The map is `--map=<tag>` after `--` (High Noon without it; RFC-044 044b).
## The navmesh carries the source hash (NavFingerprint.source_hash) in its metadata; MapNavRegion warns when it is stale.
## It runs as a scene (autoloads exist, the parse needs the nodes inside the tree):
## "$GODOT" --headless --path game res://tools/bake/bake_nav.tscn [-- --map=test_flat]           bakes and saves
## "$GODOT" --headless --path game res://tools/bake/bake_nav.tscn -- [--map=test_flat] --restamp writes the source hash of the map as it is now into the
##   saved navmesh without baking (after moving nodes of the map without changing what the bake reads; check first).
## "$GODOT" --headless --path game res://tools/bake/bake_nav.tscn -- [--map=test_flat] --check bakes again and compares with the saved file:
##   same source hash and same geometry, or it fails (exit 1). Run it twice to prove the bake is reproducible.
## Needs the project imported once (class names NavFingerprint, NavBakeSettings, MapNavRegion). Import again after writing.
## It builds the map nodes as the dedicated server does (buildings shape their boxes in _ready) but does not run the world.

const SETTINGS_PATH := "res://data/nav/nav_bake.tres"
## The manafounts under MapProps (optional: a map may have none).
const FOUNTS_PATH := "MapProps/Founts"

var _map: MapDefinition
var _nav_path := ""


func _ready() -> void:
	# After this scene finishes entering the tree, so the bake nodes can be added.
	_run.call_deferred()


func _run() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	_map = ActiveMatch.map()
	if _map == null or _map.map_scene == null:
		_fail("no map scene to bake")
		return
	_nav_path = "res://scenes/map/maps/%s/nav.res" % _map.tag
	var settings := load(SETTINGS_PATH) as NavBakeSettings
	if settings == null:
		_fail("%s does not load" % SETTINGS_PATH)
		return
	if OS.get_cmdline_user_args().has("--restamp"):
		_restamp(settings)
		return
	if not FileAccess.file_exists(_nav_path):
		if check:
			_fail("%s does not exist: bake first" % _nav_path)
			return
		# the map scene references the file, so the scene cannot load without it: an empty navmesh stands in until the bake.
		ResourceSaver.save(NavigationMesh.new(), _nav_path)
		print("bake_nav: created an empty %s so the scene loads" % _nav_path)
	var baked := await _bake(settings)
	if baked == null:
		return
	var source_hash: String = baked.get_meta(NavFingerprint.META_SOURCE)
	if check:
		_check(baked, source_hash)
		return
	baked.take_over_path(_nav_path)
	var error := ResourceSaver.save(baked, _nav_path)
	if error != OK:
		_fail("could not save %s (error %d)" % [_nav_path, error])
		return
	var regions := NavRegions.new()
	regions.build(baked)
	var sizes := Array(regions.sizes)
	sizes.sort()
	sizes.reverse()
	print("bake_nav: %d regions, biggest (polygons): %s" % [regions.component_count, sizes.slice(0, 8)])
	print("bake_nav: written %s (%d polygons, %d vertices, source %s)" % [
		_nav_path, baked.get_polygon_count(), baked.get_vertices().size(), source_hash.substr(0, 12)])
	get_tree().quit(0)


## Keeps the saved navmesh and gives it the source hash of the map as it stands.
func _restamp(settings: NavBakeSettings) -> void:
	var saved := load(_nav_path) as NavigationMesh
	var world := _map.map_scene.instantiate()
	if saved == null or world == null:
		_fail("%s or the map scene does not load" % _nav_path)
		return
	var source_hash := NavFingerprint.source_hash(world, settings)
	world.free()
	saved.set_meta(NavFingerprint.META_SOURCE, source_hash)
	if ResourceSaver.save(saved, _nav_path) != OK:
		_fail("could not save %s" % _nav_path)
		return
	print("bake_nav: restamped %s (%d polygons, source %s)" % [_nav_path, saved.get_polygon_count(), source_hash.substr(0, 12)])
	get_tree().quit(0)


## The navmesh baked from the map now, with the source hash in its metadata; null (after _fail) when it cannot be built.
func _bake(settings: NavBakeSettings) -> NavigationMesh:
	var world: Node = _map.map_scene.instantiate()
	if world == null:
		_fail("the scene of '%s' does not load" % _map.tag)
		return null
	# The hash is taken from the stored nodes, before any _ready, as the editor warning takes it.
	var source_hash := NavFingerprint.source_hash(world, settings)
	var bake_root := Node3D.new()
	bake_root.name = "BakeRoot"
	var map := world as MapRoot
	if map == null or map.terrain == null:
		_fail("the scene of '%s' is not a MapRoot with a terrain" % _map.tag)
		bake_root.free()
		world.free()
		return null
	# The terrain is required; the buildings and the founts are optional.
	var parts: Array[Node] = [map.terrain]
	if map.buildings != null:
		parts.append(map.buildings)
	var founts := map.get_node_or_null(FOUNTS_PATH)
	if founts != null:
		parts.append(founts)
	for part in parts:
		_detach(part, world)
		part.get_parent().remove_child(part)
		bake_root.add_child(part)
	world.free()
	# The tree is entered once: the terrain builds its Collision, the buildings shape their boxes in _ready.
	add_child(bake_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var navmesh := NavigationMesh.new()
	settings.apply_to(navmesh)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, geometry, bake_root)
	if not geometry.has_data():
		_fail("no source geometry: no static collider in the group %s" % NavFingerprint.GROUP)
		return null
	NavigationServer3D.bake_from_source_geometry_data(navmesh, geometry)
	if navmesh.get_polygon_count() == 0:
		_fail("the bake produced no polygons")
		return null
	navmesh.set_meta(NavFingerprint.META_SOURCE, source_hash)
	return navmesh


## The nodes moved out of the world lose it as owner, so freeing the world leaves no dangling owner.
func _detach(node: Node, world: Node) -> void:
	if node.owner == world:
		node.owner = null
	for child in node.get_children():
		_detach(child, world)


func _check(baked: NavigationMesh, source_hash: String) -> void:
	var saved := load(_nav_path) as NavigationMesh
	var problems := PackedStringArray()
	if saved == null:
		problems.append("%s does not load" % _nav_path)
	else:
		if str(saved.get_meta(NavFingerprint.META_SOURCE, "")) != source_hash:
			problems.append("the saved navmesh is stale: its source hash differs from the map's")
		if NavFingerprint.mesh_hash(saved) != NavFingerprint.mesh_hash(baked):
			problems.append("the bake is not the saved one (%d vs %d polygons)" % [baked.get_polygon_count(), saved.get_polygon_count()])
	if problems.is_empty():
		print("bake_nav: CHECK PASS (%d polygons, source %s, mesh %s)" % [
			baked.get_polygon_count(), source_hash.substr(0, 12), NavFingerprint.mesh_hash(baked).substr(0, 12)])
		get_tree().quit(0)
		return
	for problem in problems:
		print("bake_nav: FAIL %s" % problem)
	get_tree().quit(1)


func _fail(text: String) -> void:
	push_error("bake_nav: %s" % text)
	get_tree().quit(1)
