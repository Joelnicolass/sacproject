extends SceneTree

## Step 1 of 2 of the 055s materials bake (step 2: tools/bake/bake_materials_055s.py).
## Reads the materials the game builds today at run time (OriginalMaterial, from assets/original/textures/index.json) and
## writes them as files, so the game stops reading the original to dress a body:
##   scenes/bodies/materials/<owner>_<file>[_cutout].tres   one StandardMaterial3D per texture and cutout (shared by every model)
##   scenes/bodies/meshes/<tag>.res                          the static mesh of each hybrid body, with its materials
##   tools/bake/bake_materials_055s.json                     what the .py needs to save the overrides inside the 74 model scenes
## It changes no scene: the .py does, from the json.
## A model scene is read through its SceneState (no BodyModel is instanced): the `model` tag, the `surface_parts` it
## still stores and the .glb its `Model` node instances.
##
## Run:  Godot --headless --path . --script res://tools/bake/bake_materials_055s.gd
## It always quits (exit code 1 on an error, 0 otherwise) and gives up after TIMEOUT_S seconds.

const MODELS_DIR := "res://scenes/bodies/models/"
const SIZES_DIR := "res://data/catalog/body_sizes/"
const MATERIALS_DIR := "res://scenes/bodies/materials/"
const HYBRIDS_DIR := "res://scenes/bodies/meshes/"
const REPORT_PATH := "res://tools/bake/bake_materials_055s.json"
const TIMEOUT_S := 120.0
const EXPECTED_HYBRIDS := 11

var _failed := false
## material file path -> true (already written in this run)
var _written: Dictionary = {}


func _init() -> void:
	create_timer(TIMEOUT_S).timeout.connect(_on_timeout)
	var report := {"models": {}, "materials": {}, "hybrids": {}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HYBRIDS_DIR))
	for file: String in _files(MODELS_DIR, "tscn"):
		_bake_model(file, report)
	_bake_hybrids(report)
	var out := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if out == null:
		_fail("cannot write %s" % REPORT_PATH)
	else:
		out.store_string(JSON.stringify(report, "\t"))
		out.close()
	print("bake_materials_055s: models=%d materials=%d hybrids=%d" % [
		(report["models"] as Dictionary).size(), _written.size(), (report["hybrids"] as Dictionary).size()])
	quit(1 if _failed else 0)


func _on_timeout() -> void:
	push_error("bake_materials_055s: timeout")
	quit(1)


func _fail(message: String) -> void:
	_failed = true
	push_error("bake_materials_055s: " + message)


func _files(dir: String, extension: String) -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(dir):
		if name.get_extension() == extension:
			found.append(name)
	found.sort()
	return found


## One model scene -> the override of every surface that has a texture.
func _bake_model(file: String, report: Dictionary) -> void:
	var scene := load(MODELS_DIR + file) as PackedScene
	if scene == null:
		_fail("cannot load " + file)
		return
	var state := scene.get_state()
	var tag := ""
	var parts: Array = []
	for p in state.get_node_property_count(0):
		match str(state.get_node_property_name(0, p)):
			"model":
				tag = str(state.get_node_property_value(0, p))
			"surface_parts":
				parts = state.get_node_property_value(0, p)
	var glb: PackedScene = null
	for n in state.get_node_count():
		if state.get_node_name(n) == &"Model" and state.get_node_instance(n) != null:
			glb = state.get_node_instance(n)
	if tag.is_empty() or glb == null:
		_fail("%s: no `model` tag or no Model instance" % file)
		return
	var root := glb.instantiate()
	var overrides: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		var path := str(root.get_path_to(instance))
		if path == ".":
			_fail("%s: the mesh is the root of the .glb (not supported by the .py)" % file)
			continue
		for i in instance.mesh.get_surface_count():
			var part := int((parts[i] as Array)[0]) if i < parts.size() else i
			var mat := OriginalMaterial.for_label(tag, OriginalMaterial.part_label(part))
			if mat == null:
				continue
			overrides.append({"node": path, "index": instance.get_index(), "surface": i, "material": _save_material(mat, report)})
	root.free()
	(report["models"] as Dictionary)[file.get_basename()] = {"model": tag, "overrides": overrides}


## Writes the material once (name from its texture) and returns its path. The material keeps that path, so a mesh that
## holds it saves a reference to the file and not a copy.
func _save_material(mat: StandardMaterial3D, report: Dictionary) -> String:
	var texture_path := mat.albedo_texture.resource_path
	var cutout := mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var name := "%s_%s%s" % [texture_path.get_base_dir().get_file(), texture_path.get_file().get_basename(), "_cutout" if cutout else ""]
	var path := MATERIALS_DIR + name + ".tres"
	if not _written.has(path):
		mat.resource_name = name
		var err := ResourceSaver.save(mat, path, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			_fail("cannot save %s (%d)" % [path, err])
		_written[path] = true
		var uid := ResourceLoader.get_resource_uid(path)
		(report["materials"] as Dictionary)[path] = ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else ""
	return path


## The bodies that are a static mesh (no skeletal model scene): the prop .glb with the materials on its surfaces.
func _bake_hybrids(report: Dictionary) -> void:
	for file in _files(SIZES_DIR, "tres"):
		var size := load(SIZES_DIR + file)
		if size == null or bool(size.get("is_prop")):
			continue
		var tag := str(size.get("tag"))
		if ResourceLoader.exists(MODELS_DIR + tag + ".tscn"):
			continue
		var mesh := _hybrid_mesh(tag, report)
		if mesh != null:
			(report["hybrids"] as Dictionary)[tag] = HYBRIDS_DIR + tag + ".res"
	var count := (report["hybrids"] as Dictionary).size()
	if count != EXPECTED_HYBRIDS:
		_fail("%d hybrids baked, the plan lists %d" % [count, EXPECTED_HYBRIDS])


## Same lookup as BodyCatalog._prop_mesh: the first MeshInstance3D of the prop .glb, a surface per material label.
func _hybrid_mesh(tag: String, report: Dictionary) -> Mesh:
	var scene := load(OriginalAssets.prop(tag)) as PackedScene
	if scene == null:
		_fail("hybrid %s: no prop .glb" % tag)
		return null
	var root := scene.instantiate()
	var holder := root as MeshInstance3D
	if holder == null:
		holder = root.find_child("*", true, false) as MeshInstance3D
	var source: Mesh = holder.mesh if holder != null else null
	root.free()
	if source == null:
		_fail("hybrid %s: the .glb has no mesh" % tag)
		return null
	var baked := source.duplicate() as Mesh
	if baked == null or baked.get_surface_count() != source.get_surface_count() or baked.get_aabb() != source.get_aabb():
		_fail("hybrid %s: the copy of the mesh differs from the source" % tag)
		return null
	for i in baked.get_surface_count():
		var mat := OriginalMaterial.for_label(tag, baked.surface_get_name(i))
		if mat != null:
			_save_material(mat, report)
		baked.surface_set_material(i, mat)
	var path := HYBRIDS_DIR + tag + ".res"
	var err := ResourceSaver.save(baked, path)
	if err != OK:
		_fail("cannot save %s (%d)" % [path, err])
		return null
	return baked
