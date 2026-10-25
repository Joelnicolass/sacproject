extends SceneTree

## The exact check of the 055s props bake (run after tools/bake/bake_props_055s.gd). For every baked prop mesh it compares, with what
## the game builds today at run time (the prop .glb with OriginalMaterial.for_label on each surface):
##   - the surfaces: same count, same name, same primitive, same vertices, normals, UVs and indices (a turned prop: its vertices
##     turned by the pose, within 0.1 mm);
##   - the material of each surface: both null, or every stored property of the StandardMaterial3D equal (textures by file);
##   - that the .res holds its materials as references and does not depend on assets/original/props.
## Prints PROP CHECK props=<n> surfaces=<n> equal=<n> differ=<n> geometry_ok=<n> and one line per difference. Exit code 1 on any.
## Needs OriginalMaterial, which goes with 055s s5b: run it before that.
##
## Run:  Godot --headless --path . --script res://tools/bake/check_props_055s.gd

const REPORT_PATH := "res://tools/bake/bake_props_055s.json"
const PROPS_DIR := "res://assets/original/props/"
const SIZES_DIR := "res://data/catalog/body_sizes/"
const OVERRIDES_PATH := "res://data/bodies/pose_overrides.tres"
const TIMEOUT_S := 120.0
## Properties that differ by design: the saved file names the material after its texture and has a path.
const SKIP: PackedStringArray = ["resource_name", "resource_path", "resource_local_to_scene", "script"]
const TURN_TOLERANCE_M := 0.0001
const MAX_LINES := 20

var _lines := 0
var _failed := false


func _init() -> void:
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
	if not parsed is Dictionary:
		push_error("check_props_055s: cannot read %s" % REPORT_PATH)
		quit(1)
		return
	var overrides := load(OVERRIDES_PATH) as BodyPoseOverrides
	var props: Dictionary = (parsed as Dictionary)["props"]
	var surfaces := 0
	var equal := 0
	var geometry_ok := 0
	var keys := props.keys()
	keys.sort()
	for key: String in keys:
		var info: Dictionary = props[key]
		var baked := ResourceLoader.load(str(info["path"]), "", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		var source := _source(key)
		if baked == null or source == null:
			_note("%s: cannot load the baked mesh or the source" % key)
			continue
		if baked.get_surface_count() != source.get_surface_count():
			_note("%s: %d surfaces, source %d" % [key, baked.get_surface_count(), source.get_surface_count()])
			continue
		var pose := _pose(key, overrides)
		var geometry := _geometry_problem(baked, source, pose)
		if geometry.is_empty():
			geometry_ok += 1
		else:
			_note("%s: %s" % [key, geometry])
		var depends := _bad_dependency(str(info["path"]))
		if not depends.is_empty():
			_note("%s: depends on %s" % [key, depends])
		for i in baked.get_surface_count():
			surfaces += 1
			var problem := _material_problem(baked.surface_get_material(i), OriginalMaterial.for_label(key, source.surface_get_name(i)))
			if problem.is_empty():
				equal += 1
			else:
				_note("%s surface %d (%s): %s" % [key, i, source.surface_get_name(i), problem])
	print("PROP CHECK props=%d surfaces=%d equal=%d differ=%d geometry_ok=%d" % [props.size(), surfaces, equal, surfaces - equal, geometry_ok])
	quit(1 if _failed or equal != surfaces or geometry_ok != props.size() else 0)


func _on_timeout() -> void:
	push_error("check_props_055s: timeout")
	quit(1)


func _note(line: String) -> void:
	_failed = true
	_lines += 1
	if _lines <= MAX_LINES:
		print("PROP CHECK   " + line)


func _source(key: String) -> Mesh:
	for name in DirAccess.get_files_at(PROPS_DIR):
		if name.get_extension() == "glb" and name.get_basename().to_lower() == key:
			var scene := load(PROPS_DIR + name) as PackedScene
			var root := scene.instantiate() if scene != null else null
			if root == null:
				return null
			var holder := root as MeshInstance3D
			if holder == null:
				holder = root.find_child("*", true, false) as MeshInstance3D
			var found: Mesh = holder.mesh if holder != null else null
			root.free()
			return found
	return null


func _pose(key: String, overrides: BodyPoseOverrides) -> Transform3D:
	var turn := Vector3.ZERO
	for name in DirAccess.get_files_at(SIZES_DIR):
		if name.get_extension() == "tres" and name.get_basename().to_lower() == key:
			var fix: Variant = load(SIZES_DIR + name).get("upright_fix")
			if fix is PackedFloat64Array and (fix as PackedFloat64Array).size() >= 3:
				var angles := fix as PackedFloat64Array
				turn = Vector3(angles[0], angles[1], angles[2])
	if overrides != null:
		for entry in overrides.entries:
			if entry != null and entry.model.to_lower() == key:
				turn += entry.rotation_degrees
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))), Vector3.ZERO)


## "" when every surface of `baked` is `source` (turned by `pose`).
func _geometry_problem(baked: Mesh, source: Mesh, pose: Transform3D) -> String:
	var turned := pose.basis != Basis.IDENTITY
	for i in source.get_surface_count():
		if baked.surface_get_name(i) != source.surface_get_name(i):
			return "surface %d is named %s, source %s" % [i, baked.surface_get_name(i), source.surface_get_name(i)]
		if baked.surface_get_primitive_type(i) != source.surface_get_primitive_type(i):
			return "surface %d has another primitive" % i
		var a := baked.surface_get_arrays(i)
		var b := source.surface_get_arrays(i)
		var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
		if av.size() != bv.size():
			return "surface %d has %d vertices, source %d" % [i, av.size(), bv.size()]
		if not turned and av != bv:
			return "surface %d vertices differ" % i
		if turned:
			for v in av.size():
				if (pose * bv[v]).distance_to(av[v]) > TURN_TOLERANCE_M:
					return "surface %d vertex %d is not the turned source" % [i, v]
		elif a[Mesh.ARRAY_NORMAL] != b[Mesh.ARRAY_NORMAL] or a[Mesh.ARRAY_TEX_UV] != b[Mesh.ARRAY_TEX_UV]:
			return "surface %d normals or uvs differ" % i
		if a[Mesh.ARRAY_INDEX] != b[Mesh.ARRAY_INDEX]:
			return "surface %d indices differ" % i
	if not turned and baked.get_aabb() != source.get_aabb():
		return "box %s, source %s" % [str(baked.get_aabb()), str(source.get_aabb())]
	return ""


func _bad_dependency(path: String) -> String:
	for dependency in ResourceLoader.get_dependencies(path):
		if dependency.contains("assets/original/props"):
			return dependency
	return ""


## "" when the saved material is what OriginalMaterial builds (both null, or every stored property the same).
func _material_problem(saved: Material, built: StandardMaterial3D) -> String:
	if saved == null and built == null:
		return ""
	if saved == null or built == null:
		return "saved %s, runtime %s" % [str(saved), str(built)]
	if saved.get_class() != built.get_class():
		return "class %s, runtime %s" % [saved.get_class(), built.get_class()]
	for info: Dictionary in built.get_property_list():
		if (int(info["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or SKIP.has(str(info["name"])):
			continue
		var name := str(info["name"])
		var a: Variant = saved.get(name)
		var b: Variant = built.get(name)
		if a is Resource and b is Resource:
			if (a as Resource).resource_path != (b as Resource).resource_path:
				return "%s: %s, runtime %s" % [name, (a as Resource).resource_path, (b as Resource).resource_path]
		elif typeof(a) != typeof(b) or a != b:
			return "%s: %s, runtime %s" % [name, str(a), str(b)]
	return ""
