extends SceneTree

## One-time tool (RFC-035 035d): writes High Noon's content as nodes. From then on the scene is the source of truth and
## nothing reads ntts.json or widgets.json at runtime; those two files are only this tool's input.
##   scenes/world/map/high_noon_layout.tscn   Buildings (MapBuilding), Plants (Plant), NpcSpawns (NpcSpawn)
##   assets/original/maps/high_noon/sides.tres   MapSides
## It does what the old runtime code did, in the same order and with the same arithmetic, so the match digests do not move:
##  - buildings: the order of `structures`, names `Bld%03d_<tag>` (the index counts the hand-placed founts and altars too),
##    y = ground_height(x, z), `facing_deg` as the NTTS says; the ones off the land are left out with a warning;
##  - plants: the sacengine placeWidgets walk (sorted tags, one RNG draw per row, seed 17), skipped over holes and near
##    an altar (40 m) or a manafount (6 m); the founts and altars are the `jfnt` and `jaal` rows of the NTTS, the same spots
##    as Starts and Founts in high_noon.tscn;
##  - NPCs: the order of `creatures`; position y = ground + 0.2 m (the feet settle by themselves).
## Idempotent: it refuses to overwrite a file that exists (the scene may have been edited). --force overwrites.
## "$GODOT" --headless --path game --script res://tools/bake_map_layout.gd [-- --force] [--out=res://...tscn] [--sides-out=res://...tres]
## "$GODOT" --headless --path game --script res://tools/bake_map_layout.gd -- --check    (compares the saved files with the JSON and prints the counts)
## Needs the project imported once, so the class names (MapSides, NpcSpawn, MapBuilding) are registered. Import again after
## writing, so the editor knows the new scene.

const NTTS_PATH := "res://assets/original/maps/high_noon/ntts.json"
const WIDGETS_PATH := "res://assets/original/maps/high_noon/widgets.json"
const LAYOUT_OUT := "res://scenes/world/map/high_noon_layout.tscn"
const BUILDING_SCENE := "res://scenes/world/map/map_building.tscn"
const SPAWN_SCENE := "res://scenes/world/map/npc_spawn.tscn"
const PLANT_SCENE := "res://scenes/world/props/plant.tscn"
const TERRAIN_SCRIPT := "res://scenes/world/terrain.gd"
const ROOT_NAME := "HighNoonLayout"

## Rows the scene places by hand (Starts, Founts): not buildings of the layout.
const HAND_PLACED: PackedStringArray = ["jfnt", "jaal"]
const FOUNT_TAG := "jfnt"
const ALTAR_TAG := "jaal"
const NEUTRAL_SIDE := 31
## Meters above the land where a creature is put.
const SPAWN_LIFT := 0.2
const PLANT_SEED := 17
const ALTAR_CLEAR := 40.0
const FOUNT_CLEAR := 6.0
## Models of a widget tag (JAW1…). The map is James land; the look is Persephone.
const WIDGET_MODELS := {
	"JAW1": ["PCW7", "PCW6", "PCF4"],
	"JAW2": ["PCW8", "PCF3", "PCF1"],
	"JAW3": ["PCF1", "PCF2", "PCC1", "PCC2"],
	"JAW4": ["PCG2", "PCW5"],
	"JAW5": ["PGL1", "PGL2", "PCG1"],
}
## For a widget tag missing from WIDGET_MODELS.
const FALLBACK_MODELS: Array = ["PCF1", "PCF2", "PCF3", "PCF4", "PCG1", "PCG2", "PCW5", "PCW6", "PCW7", "PCW8", "PGL1", "PGL2", "PCC1", "PCC2"]

var _terrain: MeshInstance3D
var _failures: Array[String] = []


func _initialize() -> void:
	var out := LAYOUT_OUT
	var sides_out := OriginalAssets.HIGH_NOON_SIDES
	var force := false
	var check := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
		elif argument.begins_with("--sides-out="):
			sides_out = argument.substr(12)
		elif argument == "--force":
			force = true
		elif argument == "--check":
			check = true
	var ntts := _read_json(NTTS_PATH)
	var widgets := _read_json(WIDGETS_PATH)
	if ntts.is_empty() or widgets.is_empty():
		push_error("bake_map_layout: missing or empty %s or %s." % [NTTS_PATH, WIDGETS_PATH])
		quit(1)
		return
	if not _make_terrain():
		quit(1)
		return
	var plan := _plan(ntts, widgets)
	if check:
		_check(plan, ntts, out, sides_out)
		_terrain.free()
		quit(1 if not _failures.is_empty() else 0)
		return
	if not force:
		for path in [out, sides_out]:
			if FileAccess.file_exists(path):
				push_error("bake_map_layout: %s already exists and is now the source of truth. Pass --force to overwrite it." % path)
				_terrain.free()
				quit(1)
				return
	var error := _write_layout(plan, out)
	if error == OK:
		error = _write_sides(ntts, sides_out)
	_terrain.free()
	if error != OK:
		push_error("bake_map_layout: could not write the files (error %d)." % error)
		quit(1)
		return
	print("bake_map_layout: written %s (buildings %d · plants %d · npc %d) and %s" % [
		out, plan["buildings"].size(), plan["plants"].size(), plan["npcs"].size(), sides_out])
	quit(0)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## A Terrain with only its ground index, to ask is_on_ground and ground_height as the game does.
func _make_terrain() -> bool:
	var data := load(OriginalAssets.HIGH_NOON_TERRAIN) as MapTerrainData
	if data == null or not data.is_valid():
		push_error("bake_map_layout: %s is missing or invalid." % OriginalAssets.HIGH_NOON_TERRAIN)
		return false
	_terrain = MeshInstance3D.new()
	_terrain.set_script(load(TERRAIN_SCRIPT))
	_terrain.set("data", data)
	_terrain.call("_index_ground", data.vertices, data.indices)
	return true


## What goes into the scene, in tree order: {buildings, plants, npcs}, each an Array of Dictionary.
func _plan(ntts: Dictionary, widgets: Dictionary) -> Dictionary:
	var structures: Array = ntts.get("structures", [])
	return {
		"buildings": _plan_buildings(structures),
		"plants": _plan_plants(widgets, structures),
		"npcs": _plan_npcs(ntts.get("creatures", [])),
	}


func _plan_buildings(structures: Array) -> Array:
	var rows := []
	var index := 0
	for row: Dictionary in structures:
		var tag := str(row["tag"])
		index += 1
		if HAND_PLACED.has(tag):
			continue
		var x := float(row["x"])
		var z := float(row["z"])
		if not _terrain.call("is_on_ground", x, z):
			push_warning("bake_map_layout: %s (%.0f, %.0f) falls off the land; left out" % [tag, x, z])
			continue
		rows.append({
			"name": "Bld%03d_%s" % [index, tag],
			"tag": tag,
			"owner_slot": SideRelations.slot_of(int(row.get("side", NEUTRAL_SIDE))),
			"facing": float(row.get("facing", 0.0)),
			"position": Vector3(x, float(_terrain.call("ground_height", x, z)), z),
		})
	return rows


func _plan_plants(widgets: Dictionary, structures: Array) -> Array:
	var altars: Array[Vector2] = []
	var founts: Array[Vector2] = []
	for row: Dictionary in structures:
		var at := Vector2(float(row["x"]), float(row["z"]))
		if str(row["tag"]) == ALTAR_TAG:
			altars.append(at)
		elif str(row["tag"]) == FOUNT_TAG:
			founts.append(at)
	var rng := RandomNumberGenerator.new()
	rng.seed = PLANT_SEED
	var rows := []
	var tags := widgets.keys()
	tags.sort()
	for tag in tags:
		var models: Array = WIDGET_MODELS.get(tag, FALLBACK_MODELS)
		if models.is_empty():
			continue
		for row in widgets[tag]:
			var model: String = models[rng.randi() % models.size()]
			var x := float(row[0])
			var z := float(row[1])
			if not _terrain.call("is_on_ground", x, z) or not _is_clear(x, z, altars, founts):
				continue
			rows.append({
				"name": "Plant%d" % rows.size(),
				"model": model,
				"position": Vector3(x, float(_terrain.call("ground_height", x, z)), z),
				# The NTTS angle looks like degrees but sacengine reads it as radians (state.d:31352).
				"yaw": float(row[2]),
			})
	return rows


func _is_clear(x: float, z: float, altars: Array[Vector2], founts: Array[Vector2]) -> bool:
	# Same arithmetic as the old MapProps._flat_distance: the difference of the doubles, then a Vector2.
	for altar in altars:
		if Vector2(x - altar.x, z - altar.y).length() < ALTAR_CLEAR:
			return false
	for fount in founts:
		if Vector2(x - fount.x, z - fount.y).length() < FOUNT_CLEAR:
			return false
	return true


func _plan_npcs(creatures: Array) -> Array:
	var rows := []
	var index := 0
	for row: Dictionary in creatures:
		index += 1
		var tag := str(row["tag"])
		var x := float(row["x"])
		var z := float(row["z"])
		var ground := float(_terrain.call("ground_height", x, z))
		rows.append({
			"name": "Npc%02d_%s" % [index, tag],
			"tag": tag,
			"side": int(row["side"]),
			"facing": float(row.get("facing", 0.0)),
			"ntts_id": int(row.get("id", 0)),
			"position": Vector3(x, (0.0 if is_nan(ground) else ground) + SPAWN_LIFT, z),
		})
	return rows


func _write_layout(plan: Dictionary, out: String) -> Error:
	var root := Node3D.new()
	root.name = ROOT_NAME
	var buildings := _group(root, "Buildings")
	var plants := _group(root, "Plants")
	var spawns := _group(root, "NpcSpawns")
	var building_scene := load(BUILDING_SCENE) as PackedScene
	var plant_scene := load(PLANT_SCENE) as PackedScene
	var spawn_scene := load(SPAWN_SCENE) as PackedScene
	for row: Dictionary in plan["buildings"]:
		var node := _instance(building_scene, buildings, root, row["name"])
		node.set("tag", row["tag"])
		node.set("owner_slot", row["owner_slot"])
		node.set("facing_deg", row["facing"])
		node.position = row["position"]
	for row: Dictionary in plan["plants"]:
		var node := _instance(plant_scene, plants, root, row["name"])
		node.set("model", row["model"])
		node.position = row["position"]
		node.rotation.y = row["yaw"]
	for row: Dictionary in plan["npcs"]:
		var node := _instance(spawn_scene, spawns, root, row["name"])
		node.set("tag", row["tag"])
		node.set("side", row["side"])
		node.set("facing_deg", row["facing"])
		node.set("ntts_id", row["ntts_id"])
		node.position = row["position"]
	var packed := PackedScene.new()
	var error := packed.pack(root)
	root.free()
	if error != OK:
		return error
	return ResourceSaver.save(packed, out)


func _group(root: Node3D, group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	root.add_child(node)
	node.owner = root
	return node


func _instance(scene: PackedScene, parent: Node, root: Node, node_name: String) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	return node


func _write_sides(ntts: Dictionary, out: String) -> Error:
	return ResourceSaver.save(MapSides.from_rows(ntts.get("sides", [])), out)


## --check: the saved scene and sides.tres against the JSON, with the counts the game logs.
func _check(plan: Dictionary, ntts: Dictionary, layout_path: String, sides_path: String) -> void:
	var packed := load(layout_path) as PackedScene
	var root := packed.instantiate() as Node3D if packed else null
	if root == null:
		_fail("%s does not load" % layout_path)
	else:
		_check_children(root, "Buildings", plan["buildings"], func(node: Node3D, row: Dictionary) -> bool:
			return node.get("tag") == row["tag"] and node.get("owner_slot") == row["owner_slot"] \
				and Vector3(0.0, -deg_to_rad(float(node.get("facing_deg"))), 0.0) == Vector3(0.0, -deg_to_rad(row["facing"]), 0.0))
		_check_children(root, "Plants", plan["plants"], func(node: Node3D, row: Dictionary) -> bool:
			return node.get("model") == row["model"] and node.basis.is_equal_approx(Basis.from_euler(Vector3(0.0, row["yaw"], 0.0))))
		_check_children(root, "NpcSpawns", plan["npcs"], func(node: Node3D, row: Dictionary) -> bool:
			return node.get("tag") == row["tag"] and node.get("side") == row["side"] \
				and node.get("ntts_id") == row["ntts_id"] and node.get("facing_deg") == row["facing"])
		var shelters := 0
		for node in root.get_node("Buildings").get_children():
			if MapBuilding.bldg(str(node.get("tag"))).get("shelter", false):
				shelters += 1
		print("layout: npc %d · edificios %d · refugios %d · plantas %d" % [
			root.get_node("NpcSpawns").get_child_count(), root.get_node("Buildings").get_child_count(), shelters,
			root.get_node("Plants").get_child_count()])
		root.free()
	var sides := load(sides_path) as MapSides
	if sides == null:
		_fail("%s does not load" % sides_path)
	else:
		var rows := sides.to_rows()
		var expected: Array = ntts.get("sides", [])
		if rows.size() != expected.size():
			_fail("sides: %d rows, the JSON has %d" % [rows.size(), expected.size()])
		for k in mini(rows.size(), expected.size()):
			for key in ["id", "allies", "enemies", "assignment"]:
				if int(rows[k][key]) != int(expected[k][key]):
					_fail("sides row %d: %s differs" % [k, key])
	if _failures.is_empty():
		print("bake_map_layout: CHECK PASS")
	else:
		for failure in _failures:
			print("bake_map_layout: FAIL %s" % failure)


## `same` returns true when the node fits its row. Position is compared exactly (float32 equal), plants aside from the yaw.
func _check_children(root: Node, group_name: String, rows: Array, same: Callable) -> void:
	var parent := root.get_node_or_null(group_name)
	if parent == null:
		_fail("%s is missing" % group_name)
		return
	if parent.get_child_count() != rows.size():
		_fail("%s: %d nodes, expected %d" % [group_name, parent.get_child_count(), rows.size()])
		return
	for k in rows.size():
		var node := parent.get_child(k) as Node3D
		var row: Dictionary = rows[k]
		if node.name != StringName(row["name"]):
			_fail("%s[%d] is %s, expected %s (order matters)" % [group_name, k, node.name, row["name"]])
		elif node.position != row["position"]:
			_fail("%s: position differs (%s vs %s)" % [node.name, node.position, row["position"]])
		elif not same.call(node, row):
			_fail("%s: properties differ" % node.name)


func _fail(text: String) -> void:
	_failures.append(text)
