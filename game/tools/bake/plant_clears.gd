class_name PlantClears
extends RefCounted

## The clearings of a map's widgets.json plants, shared by bake_map_layout (the Plant nodes) and bake_flora_map (the
## FloraMap, RFC-054 054a): no plant within ALTAR_CLEAR of an altar or FOUNT_CLEAR of a manafount. The altars and founts
## are the NTTS structures with the tags of ALTAR_TAGS and FOUNT_TAGS (`jaal`/`jfnt` for James, one pair per land), the
## same spots as Starts and Founts in the map scene. A plant must also stand on the land (Terrain.is_on_ground).

## The altar and the manafount of each land (BuildingType flags 0x80001407 and 0x80002810), RFC-050. Same lists as
## tools/import/scaffold_map.py.
const ALTAR_TAGS: PackedStringArray = ["jaal", "ca_a", "pyal", "stal", "alt1"]
const FOUNT_TAGS: PackedStringArray = ["jfnt", "cafn", "pfon", "stmf", "font"]
const ALTAR_CLEAR := 40.0
const FOUNT_CLEAR := 6.0

var altars: Array[Vector2] = []
var founts: Array[Vector2] = []


## From the `structures` rows of ntts.json.
static func from_structures(structures: Array) -> PlantClears:
	var clears := PlantClears.new()
	for row: Dictionary in structures:
		var at := Vector2(float(row["x"]), float(row["z"]))
		if ALTAR_TAGS.has(str(row["tag"])):
			clears.altars.append(at)
		elif FOUNT_TAGS.has(str(row["tag"])):
			clears.founts.append(at)
	return clears


func is_clear(x: float, z: float) -> bool:
	# Same arithmetic as the old MapProps._flat_distance: the difference of the doubles, then a Vector2.
	for altar in altars:
		if Vector2(x - altar.x, z - altar.y).length() < ALTAR_CLEAR:
			return false
	for fount in founts:
		if Vector2(x - fount.x, z - fount.y).length() < FOUNT_CLEAR:
			return false
	return true


## A widgets.json row (x, z) gets a plant: on the land and outside every clearing.
func accepts(land: Terrain, x: float, z: float) -> bool:
	return land.is_on_ground(x, z) and is_clear(x, z)


## A Terrain with only its ground index, to ask is_on_ground and ground_height as the game does (the bake_map_layout
## arithmetic). Not in the tree: the caller frees it. Null when the map has no valid terrain.
static func land_of(map: MapDefinition) -> Terrain:
	var data := load(map.terrain_path) as MapTerrainData if not map.terrain_path.is_empty() else null
	if data == null or not data.is_valid():
		return null
	var node := MeshInstance3D.new()
	node.set_script(load("res://scenes/map/terrain/terrain.gd"))
	node.set("data", data)
	var land := node as Terrain
	land._index_ground(data.vertices, data.indices)
	return land


## widgets.json or ntts.json as a Dictionary ({} when missing or not an object).
static func read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
