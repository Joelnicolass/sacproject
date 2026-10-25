extends SceneTree

## Step 2 of 3 of the 055s props bake (step 1 and 3: tools/bake/bake_props_055s.py; the check: tools/bake/check_props_055s.gd).
## Reads the meshes the game builds today at run time (the first MeshInstance3D of assets/original/props/<tag>.glb with the
## OriginalMaterial of each surface, as BodyCatalog._prop_mesh does) and writes them as files, so a scene holds its mesh:
##   scenes/props/meshes/<file of the .glb>.res   one ArrayMesh per prop used, materials saved as references
##   scenes/bodies/materials/<owner>_<file>[_cutout].tres   a material that does not exist yet (the ones of 055s s3 are kept)
##   tools/bake/bake_props_055s.json              what the .py needs to point the scenes at the meshes, and the report
## The tags come from tools/bake/bake_props_055s_tags.json (the .py --list). A prop whose pose (BodyCatalog.pose without standing
## on its feet) is a turn gets the turn applied to its vertices; today only pcfn (the Persephone fountain, a hand turn in
## pose_overrides.tres) has one. A scale or an offset in the pose fails the bake (nothing uses them on a prop).
## Prints PROP BAKE props=<n> ... and always quits: exit code 1 on an error, 0 otherwise; gives up after TIMEOUT_S seconds.
##
## Run:  Godot --headless --path . --script res://tools/bake/bake_props_055s.gd

const TAGS_PATH := "res://tools/bake/bake_props_055s_tags.json"
const REPORT_PATH := "res://tools/bake/bake_props_055s.json"
const MESHES_DIR := "res://scenes/props/meshes/"
const MATERIALS_DIR := "res://scenes/bodies/materials/"
const SIZES_DIR := "res://data/catalog/body_sizes/"
const OVERRIDES_PATH := "res://data/bodies/pose_overrides.tres"
const PROPS_DIR := "res://assets/original/props/"
const TIMEOUT_S := 120.0

var _failed := false
var _overrides: BodyPoseOverrides
## lower case file name -> the name on disk (macOS and Windows do not tell PCF1 from pcf1)
var _glb_names: Dictionary = {}
var _size_names: Dictionary = {}
var _report := {"props": {}, "turned": [], "untextured": {}, "unused_glb": [], "stale_res": [], "materials_written": []}


func _init() -> void:
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MESHES_DIR))
	_overrides = load(OVERRIDES_PATH) as BodyPoseOverrides
	_glb_names = _names(PROPS_DIR, "glb")
	_size_names = _names(SIZES_DIR, "tres")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TAGS_PATH))
	if not parsed is Dictionary:
		_fail("cannot read %s (run bake_props_055s.py --list first)" % TAGS_PATH)
		quit(1)
		return
	var wanted: Dictionary = {}
	for tag: Variant in (parsed as Dictionary).get("tags", []):
		wanted[str(tag).to_lower()] = str(tag)
	var keys := wanted.keys()
	keys.sort()
	for key: String in keys:
		_bake(key)
	for key: String in _glb_names:
		if not wanted.has(key):
			(_report["unused_glb"] as Array).append(_glb_names[key])
	for name in DirAccess.get_files_at(MESHES_DIR):
		if name.get_extension() == "res" and not wanted.has(name.get_basename().to_lower()):
			(_report["stale_res"] as Array).append(name)
	var out := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if out == null:
		_fail("cannot write %s" % REPORT_PATH)
	else:
		out.store_string(JSON.stringify(_report, "\t"))
		out.close()
	print("PROP BAKE props=%d turned=%d untextured_props=%d unused_glb=%d stale_res=%d materials_written=%d" % [
		(_report["props"] as Dictionary).size(), (_report["turned"] as Array).size(), (_report["untextured"] as Dictionary).size(),
		(_report["unused_glb"] as Array).size(), (_report["stale_res"] as Array).size(), (_report["materials_written"] as Array).size()])
	quit(1 if _failed else 0)


func _on_timeout() -> void:
	push_error("bake_props_055s: timeout")
	quit(1)


func _fail(message: String) -> void:
	_failed = true
	push_error("bake_props_055s: " + message)


func _names(dir: String, extension: String) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(dir):
		if name.get_extension() == extension:
			out[name.get_basename().to_lower()] = name.get_basename()
	return out


func _bake(key: String) -> void:
	if not _glb_names.has(key):
		_fail("%s: no %s.glb in %s" % [key, key, PROPS_DIR])
		return
	var file_name: String = _glb_names[key]
	var source := _source_mesh(PROPS_DIR + file_name + ".glb", key)
	if source == null:
		return
	var pose := _pose(key)
	if pose.basis.get_scale().distance_to(Vector3.ONE) > 1e-6 or pose.origin != Vector3.ZERO:
		_fail("%s: the pose has a scale or an offset (%s); only turns are baked" % [key, str(pose)])
		return
	var turned := pose.basis != Basis.IDENTITY
	var baked: ArrayMesh = _turn(source, pose) if turned else (source.duplicate() as ArrayMesh)
	if baked == null or baked.get_surface_count() != source.get_surface_count():
		_fail("%s: the copy of the mesh differs from the source" % key)
		return
	if not turned and baked.get_aabb() != source.get_aabb():
		_fail("%s: the copy has another box" % key)
		return
	var paths: Array = []
	var untextured: Array = []
	for i in baked.get_surface_count():
		var label := source.surface_get_name(i)
		var built := OriginalMaterial.for_label(key, label)
		if built == null:
			untextured.append(label)
			baked.surface_set_material(i, null)
			continue
		var saved := _saved_material(built)
		baked.surface_set_material(i, saved)
		paths.append(saved.resource_path)
	var path := MESHES_DIR + file_name + ".res"
	var err := ResourceSaver.save(baked, path)
	if err != OK:
		_fail("cannot save %s (%d)" % [path, err])
		return
	var uid := ResourceLoader.get_resource_uid(path)
	var props := _report["props"] as Dictionary
	props[key] = {"path": path, "uid": ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else "",
		"surfaces": baked.get_surface_count(), "materials": paths, "turned": turned, "aabb": var_to_str(baked.get_aabb())}
	if turned:
		(_report["turned"] as Array).append(key)
	if not untextured.is_empty():
		(_report["untextured"] as Dictionary)[key] = untextured


## The first MeshInstance3D of the prop .glb (the same lookup as BodyCatalog._prop_mesh), freed with its scene.
func _source_mesh(glb: String, key: String) -> Mesh:
	var scene := load(glb) as PackedScene
	if scene == null:
		_fail("%s: cannot load %s" % [key, glb])
		return null
	var root := scene.instantiate()
	var holder := root as MeshInstance3D
	if holder == null:
		holder = root.find_child("*", true, false) as MeshInstance3D
	var found: Mesh = holder.mesh if holder != null else null
	root.free()
	if found == null:
		_fail("%s: the .glb has no mesh" % key)
	return found


## BodyCatalog.pose(tag, false) without the catalog: the turn of the upright fix plus the hand correction of pose_overrides.tres.
func _pose(key: String) -> Transform3D:
	var turn := Vector3.ZERO
	var at := Vector3.ZERO
	var size := Vector3.ONE
	if _size_names.has(key):
		var record := load(SIZES_DIR + str(_size_names[key]) + ".tres")
		var fix: Variant = record.get("upright_fix") if record != null else null
		if fix is PackedFloat64Array and (fix as PackedFloat64Array).size() >= 3:
			var angles := fix as PackedFloat64Array
			turn = Vector3(angles[0], angles[1], angles[2])
	var entry: BodyPoseOverride = null
	if _overrides != null:
		for candidate in _overrides.entries:
			if candidate != null and candidate.model.to_lower() == key:
				entry = candidate
	if entry != null:
		turn += entry.rotation_degrees
		at = entry.position_offset
		size = entry.model_scale
	var radians := Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))
	return Transform3D(Basis.from_euler(radians) * Basis.from_scale(size), at)


## A copy of `source` with `pose` applied to its vertices and normals (and tangents), surface names kept.
func _turn(source: Mesh, pose: Transform3D) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in source.get_surface_count():
		var arrays := source.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			vertices[v] = pose * vertices[v]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		if normals is PackedVector3Array:
			var turned_normals := normals as PackedVector3Array
			for n in turned_normals.size():
				turned_normals[n] = (pose.basis * turned_normals[n]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = turned_normals
		var tangents: Variant = arrays[Mesh.ARRAY_TANGENT]
		if tangents is PackedFloat32Array:
			var values := tangents as PackedFloat32Array
			for t in values.size() / 4:
				var direction := (pose.basis * Vector3(values[t * 4], values[t * 4 + 1], values[t * 4 + 2])).normalized()
				values[t * 4] = direction.x
				values[t * 4 + 1] = direction.y
				values[t * 4 + 2] = direction.z
			arrays[Mesh.ARRAY_TANGENT] = values
		out.add_surface_from_arrays(source.surface_get_primitive_type(i), arrays)
		out.surface_set_name(i, source.surface_get_name(i))
	return out


## The saved file of a runtime material: the one that is already there (055s s3 wrote most), else it is written now.
func _saved_material(built: StandardMaterial3D) -> StandardMaterial3D:
	var texture_path := built.albedo_texture.resource_path
	var cutout := built.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var name := "%s_%s%s" % [texture_path.get_base_dir().get_file(), texture_path.get_file().get_basename(), "_cutout" if cutout else ""]
	var path := MATERIALS_DIR + name + ".tres"
	if not ResourceLoader.exists(path):
		built.resource_name = name
		var err := ResourceSaver.save(built, path, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			_fail("cannot save %s (%d)" % [path, err])
		(_report["materials_written"] as Array).append(path)
	return load(path) as StandardMaterial3D
