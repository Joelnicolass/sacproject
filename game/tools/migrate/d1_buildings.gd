extends Node

## One-off migration of the 196 BuildingType to scenes (RFC-055 055d-d1). Deleted in the last commit of d1.
##   snapshot <dir> <out.json>    what a MapBuilding of every type in <dir> is (health, groups, box, collision)
##   shape <gods.json>            with the OLD code: one scene per type (parts, Footprint, VegetationClear), its ruin, the .tres in the new shape
##   verify <dir> <before.json>   with the NEW code: the same snapshot again; exit 1 if anything differs
##   names <gods.json> <out.tsv>  checks the names and writes "old path<TAB>new path" for the .tres of data/catalog/buildings/
## "$GODOT" --headless --path game res://tools/migrate/d1_buildings.tscn -- <mode> ...

const LEGACY_DIR := "res://data/catalog/buildings/"
const SCENE_DIR := "res://scenes/structures/buildings/"
const BUILDING_SCENE := "res://scenes/map/map_building.tscn"
const NAMES_CSV := "res://tools/migrate/d1_building_names.csv"
const GODS := {"JA_A": "james", "PY_A": "pyro", "ST_A": "stratos", "char": "charnel", "ethr": "ether", "prsc": "persephone"}
const MAX_CLEAR_M := 100.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var code := 2
	match args[0] if not args.is_empty() else "":
		"snapshot":
			code = _write_json(args[2], _snapshot(args[1]))
		"shape":
			code = _shape(args[1])
		"verify":
			code = _verify(args[1], args[2])
		"names":
			code = _names(args[1], args[2])
		_:
			push_error("d1_buildings: snapshot | shape | verify | names")
	get_tree().quit(code)


func _tres(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with(".tres"):
			found.append(entry)
	found.sort()
	return found


func _write_json(path: String, data: Variant) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("d1_buildings: cannot write %s" % path)
		return 1
	file.store_string(JSON.stringify(data, "\t", true))
	return 0


func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _aabb(box: AABB) -> Array:
	return [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]


func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## Everything a MapBuilding says about its type, keyed by tag.
func _snapshot(dir: String) -> Dictionary:
	var packed := load(BUILDING_SCENE) as PackedScene
	var out := {}
	for file in _tres(dir):
		var type: Resource = load(dir + file)
		var node: Node = packed.instantiate()
		node.set("building", type)
		add_child(node)
		var health: Node = node.get("health")
		var shape: CollisionShape3D = node.get("collision")
		var groups := []
		for group in node.get_groups():
			if not str(group).begins_with("_"):
				groups.append(str(group))
		groups.sort()
		var box: AABB = node.call("hit_box")
		var melee: Dictionary = node.call("melee_profile")
		var bar: Node3D = node.get("health_bar")
		out[type.get("tag")] = {
			"hp": [health.get("maximum"), health.get("current")], "shelter": node.get("shelter"), "groups": groups,
			"box": _aabb(box), "melee": [melee["evasion"], melee["resistance"], melee["reach"], melee["height"]],
			"collision": [shape.disabled, node.collision_layer, _vec((shape.shape as BoxShape3D).size), _vec(shape.position)],
			"bar": _vec(bar.position),
		}
		remove_child(node)
		node.free()
	return out


func _verify(dir: String, before_path: String) -> int:
	var before: Dictionary = _read_json(before_path)
	var after := _snapshot(dir)
	var bad := 0
	if before.size() != after.size():
		push_error("d1_buildings: %d types before, %d after" % [before.size(), after.size()])
		bad += 1
	for tag in before:
		if not after.has(tag):
			push_error("d1_buildings: %s is gone" % tag)
			bad += 1
		elif JSON.stringify(before[tag], "", true) != JSON.stringify(JSON.parse_string(JSON.stringify(after[tag])), "", true):
			push_error("d1_buildings: %s differs\n  before %s\n  after  %s" % [tag, JSON.stringify(before[tag]), JSON.stringify(after[tag])])
			bad += 1
	print("d1_buildings verify: %d types, %d differ" % [after.size(), bad])
	return 1 if bad > 0 else 0


# ---- shape ----------------------------------------------------------------------------------------------------------

func _shape(gods_path: String) -> int:
	var packed := load(BUILDING_SCENE) as PackedScene
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var gods := {}
	var ruins := 0
	var clamped := PackedStringArray()
	for file in _tres(LEGACY_DIR):
		var type: Resource = load(LEGACY_DIR + file)
		var tag: String = type.get("tag")
		var node: Node = packed.instantiate()
		node.set("building", type)
		add_child(node)
		var ground: bool = type.get("ground")
		var box: AABB = node.call("hit_box")
		var holders: Array = (node.get("visuals") as Node3D).get_children()
		var parts: Array = []
		var ruin_parts: Array = []
		var used := {}
		var has_box := false
		var index := 0
		for component: Dictionary in type.get("components"):
			var model := str(component.get("tag", ""))
			if model.is_empty():
				continue
			var holder := holders[index] as Node3D
			index += 1
			var part_name := _part_name(str(component.get("kind", "")), used)
			parts.append({"name": part_name, "pos": holder.position, "yaw": holder.rotation.y, "model": model})
			var ruin := str(component.get("destroyed", ""))
			if not ruin.is_empty() and BodyCatalog.has_model(ruin):
				ruin_parts.append({"name": part_name, "pos": holder.position, "yaw": holder.rotation.y, "model": ruin})
			if BodyCatalog.has_model(model) and BodyCatalog.info(model).get("box", []).size() == 6:
				has_box = true
		var health_max: float = type.get("max_health")
		if health_max != floorf(health_max):
			push_error("d1_buildings: %s has a fractional max_health" % tag)
			return 1
		remove_child(node)
		node.free()
		var inset := 0.5 if has_box else 0.0
		var clear := Vector4(0.0, 0.0, 0.0, 0.0)
		if not ground:
			var radius := 0.5 * sqrt(box.size.x * box.size.x + box.size.z * box.size.z) + 1.0
			if radius > MAX_CLEAR_M:
				clamped.append("%s %.1f" % [tag, radius])
				radius = MAX_CLEAR_M
			var center := box.position + box.size * 0.5
			clear = Vector4(center.x, center.z, radius, 1.0)
		_save(SCENE_DIR + tag + ".tscn", _scene_text(tag, parts, box, inset, clear))
		var ruin_path := ""
		if not ruin_parts.is_empty():
			ruin_path = SCENE_DIR + tag + "_ruin.tscn"
			_save(ruin_path, _scene_text(tag + "_ruin", ruin_parts, AABB(), 0.0, Vector4(0, 0, 0, 0), false))
			ruins += 1
		_save(LEGACY_DIR + file, _type_text(type, SCENE_DIR + tag + ".tscn", ruin_path))
		gods[tag] = GODS.get(str(type.get("tileset")), "")
	print("d1_buildings shape: %d scenes, %d ruins, clear radius clamped to %.0f m: %s" % [gods.size(), ruins, MAX_CLEAR_M, ", ".join(clamped)])
	return _write_json(gods_path, gods)


func _part_name(kind: String, used: Dictionary) -> String:
	var clean := kind.replace("!", "")
	var part_name := (clean.substr(0, 1).to_upper() + clean.substr(1).to_lower()) if not clean.is_empty() else "Part"
	var unique := part_name
	var n := 2
	while used.has(unique):
		unique = "%s%d" % [part_name, n]
		n += 1
	used[unique] = true
	return unique


func _save(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


func _scene_text(root_name: String, parts: Array, box: AABB, inset: float, clear: Vector4, with_footprint := true) -> String:
	var text := "[gd_scene format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://scenes/bodies/body_visual.gd\" id=\"1_visual\"]\n"
	if with_footprint:
		text += "[ext_resource type=\"Script\" path=\"res://scenes/structures/building_footprint.gd\" id=\"2_footprint\"]\n"
		if clear.z > 0.0:
			text += "[ext_resource type=\"Script\" path=\"res://scenes/look/grass/vegetation_clear.gd\" id=\"3_clear\"]\n"
	text += "\n[node name=\"%s\" type=\"Node3D\"]\n" % root_name.to_pascal_case()
	for part: Dictionary in parts:
		text += "\n[node name=\"%s\" type=\"Node3D\" parent=\".\"]\n" % part["name"]
		var pos: Vector3 = part["pos"]
		if pos != Vector3.ZERO:
			text += "position = %s\n" % var_to_str(pos)
		if float(part["yaw"]) != 0.0:
			text += "rotation = %s\n" % var_to_str(Vector3(0.0, part["yaw"], 0.0))
		text += "\n[node name=\"Mesh\" type=\"MeshInstance3D\" parent=\"%s\"]\nscript = ExtResource(\"1_visual\")\nmodel = \"%s\"\nstand_on_feet = false\n" % [part["name"], part["model"]]
	if with_footprint:
		text += "\n[node name=\"Footprint\" type=\"Node3D\" parent=\".\"]\nscript = ExtResource(\"2_footprint\")\nhit_box = %s\ninset = %s\n" % [var_to_str(box), var_to_str(inset)]
		if clear.z > 0.0:
			text += "\n[node name=\"VegetationClear\" type=\"Node3D\" parent=\".\"]\nposition = %s\nscript = ExtResource(\"3_clear\")\nradius_m = %s\n" % [var_to_str(Vector3(clear.x, 0.0, clear.y)), var_to_str(snappedf(clear.z, 0.01))]
	return text


func _type_text(type: Resource, scene_path: String, ruin_path: String) -> String:
	var text := "[gd_resource type=\"Resource\" script_class=\"BuildingType\" format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://scenes/structures/building_type.gd\" id=\"1_type\"]\n"
	text += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2_scene\"]\n" % scene_path
	if not ruin_path.is_empty():
		text += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"3_ruin\"]\n" % ruin_path
	text += "\n[resource]\nscript = ExtResource(\"1_type\")\ntag = \"%s\"\n" % type.get("tag")
	if float(type.get("max_health")) > 0.0:
		text += "max_health = %s\n" % var_to_str(float(type.get("max_health")))
	if type.get("shelter"):
		text += "shelters_peasants = true\n"
	if type.get("ground"):
		text += "flattens_ground = true\n"
	text += "scene = ExtResource(\"2_scene\")\n"
	if not ruin_path.is_empty():
		text += "ruin_scene = ExtResource(\"3_ruin\")\n"
	return text


# ---- names ----------------------------------------------------------------------------------------------------------

func _names(gods_path: String, out_path: String) -> int:
	var gods: Dictionary = _read_json(gods_path)
	var proposed := {}
	var csv := FileAccess.open(NAMES_CSV, FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			proposed[row[0]] = row[1]
	var taken := {}
	var seen := {}
	var lines := PackedStringArray()
	for file in _tres(LEGACY_DIR):
		var type: Resource = load(LEGACY_DIR + file)
		var tag: String = type.get("tag")
		var human: String = proposed.get(tag, "%s_%s" % [gods.get(tag, ""), tag])
		if taken.has(human):
			push_error("d1_buildings: the name %s is taken by %s and %s" % [human, taken[human], tag])
			return 1
		taken[human] = tag
		seen[tag] = true
		lines.append("%s\t%s\t%s" % [tag, file, human])
	for tag in proposed:
		if not seen.has(tag):
			push_error("d1_buildings: the CSV names %s, which has no .tres" % tag)
			return 1
	print("d1_buildings names: %d types, %d named by the CSV" % [lines.size(), proposed.size()])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	return 0
