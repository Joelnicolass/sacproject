extends RefCounted

## RFC-067 (P3) case of rules_suite: an optional surface map that is missing breaks nothing.
##   - every texture a material of scenes/bodies/materials/ names exists (a deleted PNG is an error at load);
##   - a map that is switched on has its texture (normal, AO, roughness, emission), so the inspector never shows an empty slot that draws;
##   - a mesh whose material has a normal map has tangents: the props and hybrid bodies are saved .res (their surface format must
##     carry ARRAY_FORMAT_TANGENT, and where the data is readable the tangents stand square to the normals); the animated models come
##     from a .glb imported with meshes/ensure_tangents=true.
## Prints SURFACE REFS materials=<n> missing=<n> empty_slots=<n> normal_mapped=<n> meshes_checked=<n> no_tangents=<n> glb_without_tangents=<n>.
## Not: the generated maps themselves (surface_maps_cases, P1) nor how the relief looks (debug/look/surface_lab, P4).

const MATERIALS_DIR := "res://scenes/bodies/materials/"
const MESH_DIRS: PackedStringArray = ["res://scenes/props/meshes/", "res://scenes/bodies/meshes/"]
const MODEL_IMPORT_DIRS: PackedStringArray = ["res://assets/original/models/", "res://assets/custom/models/"]
const MAX_LINES := 12
## A tangent counts as square to its normal under this |dot|; this share of the vertices must be.
const SQUARE_DOT := 0.1
const SQUARE_SHARE := 0.95


func run(_host: Node) -> Dictionary:
	var notes := PackedStringArray()
	var materials := 0
	var missing := 0
	var empty_slots := 0
	var normal_mapped: Dictionary = {}
	for file in DirAccess.get_files_at(MATERIALS_DIR):
		if not file.ends_with(".tres"):
			continue
		materials += 1
		var path := MATERIALS_DIR + file
		var gone := _missing_refs(path)
		missing += gone.size()
		for ref in gone:
			_note(notes, "%s: names %s, which does not exist" % [file, ref])
		if not gone.is_empty():
			continue
		var material := load(path) as BaseMaterial3D
		if material == null:
			continue
		for slot in _empty_slots(material):
			empty_slots += 1
			_note(notes, "%s: %s is on with no texture" % [file, slot])
		if material.normal_enabled and material.normal_texture != null:
			normal_mapped[path] = true
	var meshes := _check_mesh_tangents(normal_mapped, notes)
	var glb_bad := _glb_without_tangents(notes)
	print("SURFACE REFS materials=%d missing=%d empty_slots=%d normal_mapped=%d meshes_checked=%d no_tangents=%d glb_without_tangents=%d" % [
		materials, missing, empty_slots, normal_mapped.size(), meshes[0], meshes[1], glb_bad])
	for line in notes:
		print("SURFACE REFS   " + line)
	var ok: bool = materials > 0 and missing == 0 and empty_slots == 0 and meshes[1] == 0 and glb_bad == 0
	return {"surface_refs": {"ok": ok, "materials": materials, "missing": missing, "empty_slots": empty_slots,
		"normal_mapped": normal_mapped.size(), "no_tangents": meshes[1], "notes": notes}}


## The res:// paths of the .tres's ext_resources that are not there (read from the text, so a missing one does not load).
func _missing_refs(path: String) -> PackedStringArray:
	var gone := PackedStringArray()
	var text := FileAccess.get_file_as_string(path)
	var pattern := RegEx.create_from_string("\\[ext_resource[^\\]]*path=\"([^\"]+)\"")
	for found: RegExMatch in pattern.search_all(text):
		var ref := found.get_string(1)
		if not ResourceLoader.exists(ref):
			gone.append(ref)
	return gone


## The maps that are switched on with no texture to read.
func _empty_slots(material: BaseMaterial3D) -> PackedStringArray:
	var slots := PackedStringArray()
	if material.normal_enabled and material.normal_texture == null:
		slots.append("normal map")
	if material.ao_enabled and material.ao_texture == null:
		slots.append("ambient occlusion")
	if material.emission_enabled and material.emission_texture == null and material.emission == Color.BLACK:
		slots.append("emission")
	if material.heightmap_enabled and material.heightmap_texture == null:
		slots.append("height map")
	return slots


## [surfaces checked, surfaces without tangents] over the saved meshes whose surface material has a normal map.
func _check_mesh_tangents(normal_mapped: Dictionary, notes: PackedStringArray) -> Array[int]:
	var checked := 0
	var bad := 0
	if normal_mapped.is_empty():
		return [checked, bad]
	for dir in MESH_DIRS:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".res"):
				continue
			var mesh := load(dir + file) as ArrayMesh
			if mesh == null:
				continue
			for i in mesh.get_surface_count():
				var material := mesh.surface_get_material(i)
				if material == null or not normal_mapped.has(material.resource_path):
					continue
				checked += 1
				var why := _tangent_problem(mesh, i)
				if why != "":
					bad += 1
					_note(notes, "%s surface %d: %s (tools/bake/add_tangents.gd)" % [file, i, why])
	return [checked, bad]


## Empty when the surface has usable tangents; else why not.
func _tangent_problem(mesh: ArrayMesh, surface: int) -> String:
	if (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_TANGENT) == 0:
		return "no tangents in its format"
	var arrays := mesh.surface_get_arrays(surface)
	if arrays.is_empty() or arrays[Mesh.ARRAY_TANGENT] == null or arrays[Mesh.ARRAY_NORMAL] == null:
		return ""  # the data is not readable here (no renderer): the format bit is what can be checked
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	if normals.is_empty() or tangents.size() != normals.size() * 4:
		return "tangent count does not match the vertices"
	var square := 0
	for v in normals.size():
		var tangent := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
		if tangent.length() > 0.5 and absf(tangent.normalized().dot(normals[v])) < SQUARE_DOT:
			square += 1
	if float(square) / normals.size() < SQUARE_SHARE:
		return "tangents are not square to the normals (%d of %d)" % [square, normals.size()]
	return ""


## Animated models (.glb) imported without meshes/ensure_tangents=true: a normal map on them would draw wrong.
func _glb_without_tangents(notes: PackedStringArray) -> int:
	var bad := 0
	for dir in MODEL_IMPORT_DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".glb.import"):
				continue
			if FileAccess.get_file_as_string(dir + file).find("meshes/ensure_tangents=true") < 0:
				bad += 1
				_note(notes, "%s: imported without meshes/ensure_tangents=true" % file)
	return bad


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)
