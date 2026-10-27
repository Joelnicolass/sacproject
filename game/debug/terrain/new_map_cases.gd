extends SceneTree

## Checks «Mapa nuevo» without the editor (addons/terrain_tools/new_map/new_map_files.gd and scenes/map/maps/_template/):
##  - the tags it refuses (an existing map, `Mi-Mapa`, `_x`, empty) and the empty name, each with its reason;
##  - the template's pictures: heights.png 256² 16-bit all 100, ground_roles.png 256² all (255,0,0,0), no void.png, no
##    _template.tres, and the catalog does not list it;
##  - the copy of the pictures into a work folder: the same bytes, its .import without a uid and without "_template";
##  - the scene rebuilt in memory from the template (with test_flat's imported pictures): one terrain.tscn, two
##    player_start.tscn and three manafount.tscn instances, nothing of _template left, each WizardSpot 30 m ± 0.1 from its
##    altar and turned (+Z) toward the nearest fount;
##  - the MapDefinition it writes: tag, name, scene, navmesh, two seats, no tiles or light.
## Prints NEW MAP CASES PASS or FAIL. Needs the project imported once (test_flat's pictures). Not: importing, baking,
## opening or validating in the editor (agent/scripts/new_map_probe.sh does that).
## "$GODOT" --headless --path game --script res://debug/terrain/new_map_cases.gd

const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")
const Png16 := preload("res://addons/terrain_tools/png16.gd")
const WORK_DIR := "user://new_map_cases"
const SOURCE_MAP := "res://scenes/map/maps/test_flat"
const SIDE := 256
const SPOT_M := 30.0

var _failed := PackedStringArray()


func _initialize() -> void:
	_refusals()
	_template_pictures()
	_copied_pictures()
	_scene_in_memory()
	_definition()
	for name in _failed:
		print("  FAIL ", name)
	print("NEW MAP CASES %s" % ("PASS" if _failed.is_empty() else "FAIL (%d)" % _failed.size()))
	quit(0 if _failed.is_empty() else 1)


func _check(name: String, ok: bool) -> void:
	if not ok:
		_failed.append(name)


func _refusals() -> void:
	_check("a fresh tag is accepted", NewMapFiles.refusal("cases_fresh_tag", "Mapa").is_empty())
	for tag: String in ["test_flat", "Mi-Mapa", "_x", "", "9lives"]:
		_check("tag «%s» is refused" % tag, not NewMapFiles.refusal(tag, "Mapa").is_empty())
	_check("an empty name is refused", not NewMapFiles.refusal("cases_fresh_tag", "  ").is_empty())


func _template_pictures() -> void:
	var heights := Png16.read_file(NewMapFiles.TEMPLATE_DIR.path_join("heights.png"))
	var flat := heights.error.is_empty() and heights.width == SIDE and heights.height == SIDE and heights.bit_depth == 16
	for sample in heights.samples:
		flat = flat and sample == 100
	_check("template heights.png is 256² 16-bit, all 100", flat and heights.samples.size() == SIDE * SIDE)
	var roles := Image.load_from_file(ProjectSettings.globalize_path(NewMapFiles.TEMPLATE_DIR.path_join("ground_roles.png")))
	var grass := roles != null and roles.get_width() == SIDE and roles.get_height() == SIDE
	if grass:
		roles.convert(Image.FORMAT_RGBA8)
		var bytes := roles.get_data()
		for i in range(0, bytes.size(), 4):
			grass = grass and bytes[i] == 255 and bytes[i + 1] == 0 and bytes[i + 2] == 0 and bytes[i + 3] == 0
	_check("template ground_roles.png is 256², all (255,0,0,0)", grass)
	_check("template has no void.png", not FileAccess.file_exists(NewMapFiles.TEMPLATE_DIR.path_join("void.png")))
	_check("template has no _template.tres", not FileAccess.file_exists(NewMapFiles.TEMPLATE_DIR.path_join("_template.tres")))
	_check("the catalog does not list _template", not MapCatalog.shared().all_tags().has("_template"))


func _copied_pictures() -> void:
	var folder := WORK_DIR.path_join("pictures")
	var written := NewMapFiles.write_pictures(folder)
	_check("write_pictures writes 3 pictures and 3 .import", written.size() == 6)
	for file in NewMapFiles.PICTURES:
		var source := NewMapFiles.TEMPLATE_DIR.path_join(file)
		var target := folder.path_join(file)
		_check("%s copied byte for byte" % file, FileAccess.get_file_as_bytes(source) == FileAccess.get_file_as_bytes(target))
		var text := FileAccess.get_file_as_string(target + ".import")
		_check("%s.import has no uid" % file, not text.is_empty() and not text.contains("uid="))
		_check("%s.import names nothing of _template" % file, not text.contains("_template"))
		_check("%s.import names the copy" % file, text.contains(target) and text.contains(target.md5_text()))
		var params := FileAccess.get_file_as_string(source + ".import").get_slice("[params]", 1)
		_check("%s.import keeps the template's params" % file, not params.is_empty() and text.ends_with(params))


func _scene_in_memory() -> void:
	var heights := load(SOURCE_MAP.path_join("heights.png")) as TerrainHeights
	var roles := load(SOURCE_MAP.path_join("ground_roles.png")) as Texture2D
	var nav := load(SOURCE_MAP.path_join("nav.res")) as NavigationMesh
	var packed := NewMapFiles.scene_for(heights, roles, nav)
	_check("scene_for packs the template", packed != null)
	if packed == null:
		return
	var state := packed.get_state()
	var instances := {}
	for i in state.get_node_count():
		var scene := state.get_node_instance(i)
		if scene != null:
			instances[scene.resource_path.get_file()] = int(instances.get(scene.resource_path.get_file(), 0)) + 1
	_check("one terrain.tscn instance", instances.get("terrain.tscn", 0) == 1)
	_check("two player_start.tscn instances", instances.get("player_start.tscn", 0) == 2)
	_check("three manafount.tscn instances", instances.get("manafount.tscn", 0) == 3)
	var map := packed.instantiate() as MapRoot
	_check("the scene's root is a MapRoot", map != null)
	if map == null:
		return
	_check("Terrain reads the given pictures", map.terrain.heights == heights and map.terrain.ground_roles == roles)
	_check("NavRegion holds the given navmesh", map.nav_region.navigation_mesh == nav)
	_check("the scene is not an instance of the template", map.scene_file_path.is_empty())
	_check("LifeSpots and Vegetation are there, empty", _empty_child(map, "LifeSpots") and _empty_child(map, "Vegetation"))
	_spots(map)
	map.free()


func _empty_child(map: Node, child: String) -> bool:
	var node := map.find_child(child, false)
	return node != null and node.get_child_count() == 0


## Each WizardSpot 30 m from its altar, its +Z toward the nearest fount (the turn test_flat's spots have).
func _spots(map: MapRoot) -> void:
	var founts: Array[Vector3] = []
	for fount in map.find_child("Founts", true).get_children():
		founts.append((fount as Node3D).transform.origin)
	_check("two starts", map.starts.get_child_count() == 2)
	for start: Node3D in map.starts.get_children():
		var spot := start.find_child("WizardSpot", false) as Node3D
		var altar := start.find_child("Altar", false) as Node3D
		if spot == null or altar == null:
			_check("%s has an Altar and a WizardSpot" % start.name, false)
			continue
		var at := start.transform * spot.transform
		var altar_at := (start.transform * altar.transform).origin
		_check("%s: WizardSpot 30 m from the altar" % start.name, absf(at.origin.distance_to(altar_at) - SPOT_M) <= 0.1)
		var nearest := founts[0]
		for fount in founts:
			if fount.distance_to(at.origin) < nearest.distance_to(at.origin):
				nearest = fount
		var toward := (nearest - at.origin) * Vector3(1, 0, 1)
		_check("%s: WizardSpot turned to the nearest fount" % start.name, at.basis.z.normalized().dot(toward.normalized()) > 0.99)


func _definition() -> void:
	var folder := WORK_DIR.path_join("definition")
	DirAccess.make_dir_recursive_absolute(folder)
	_check("write_nav", NewMapFiles.write_nav(folder).is_empty())
	var packed := NewMapFiles.scene_for(load(SOURCE_MAP.path_join("heights.png")), load(SOURCE_MAP.path_join("ground_roles.png")),
			load(folder.path_join(NewMapFiles.NAV_FILE)))
	_check("scene saved", packed != null and ResourceSaver.save(packed, folder.path_join(NewMapFiles.SCENE_FILE)) == OK)
	_check("write_definition", NewMapFiles.write_definition(folder, &"cases_map", " Mapa de prueba ").is_empty())
	var definition := ResourceLoader.load(folder.path_join("cases_map.tres"), "", ResourceLoader.CACHE_MODE_IGNORE) as MapDefinition
	_check("the definition loads", definition != null)
	if definition == null:
		return
	_check("definition tag and name", definition.tag == &"cases_map" and definition.display_name == "Mapa de prueba")
	_check("definition scene and navmesh", definition.map_scene != null and definition.nav != null)
	_check("definition: two seats, no tiles or light", definition.player_starts == 2 and definition.tiles == null and definition.light == null)
	_check("definition: offered in rooms", definition.room_selectable and definition.playable)
