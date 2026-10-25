extends RefCounted

## 055s (s5a) case of rules_suite: the props are meshes saved in scenes/props/meshes/, and every use holds one.
##   - every .res there loads as an ArrayMesh with at least one surface; `mesh` counts those whose surfaces all have a material;
##   - an orphan is a mesh no scene or .tres under scenes/ and data/ names (it should be none);
##   - every part of a building (MeshInstance3D under Visuals) has a mesh, and so has every species, shot look and map prop scene.
## Prints PROP FACTS props=<n> mesh=<n> orphans=<m> and PROP FACTS uses ... (the detail of who holds a mesh).

const MESHES_DIR := "res://scenes/props/meshes/"
const BUILDINGS_DIR := "res://scenes/structures/buildings/"
const SPECIES_DIR := "res://data/vegetation/species/"
const SHOTS_DIR := "res://data/shots/"
const SCAN_DIRS: PackedStringArray = ["res://scenes/", "res://data/"]
const MAX_LINES := 12


func run(_host: Node) -> Dictionary:
	var notes := PackedStringArray()
	var props := 0
	var with_mesh := 0
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(MESHES_DIR):
		if not file.ends_with(".res"):
			continue
		props += 1
		names.append(file)
		var mesh := load(MESHES_DIR + file) as Mesh
		if mesh == null or mesh.get_surface_count() == 0:
			_note(notes, "%s: no surfaces" % file)
			continue
		var dressed := true
		for i in mesh.get_surface_count():
			dressed = dressed and mesh.surface_get_material(i) != null
		with_mesh += 1 if dressed else 0
		if not dressed:
			_note(notes, "%s: a surface has no material" % file)
	var orphans := _orphans(names)
	for file in orphans:
		_note(notes, "orphan: " + file)
	var parts := _building_parts(notes)
	var species := _resources_with_mesh(SPECIES_DIR, notes)
	var shots := _shots(notes)
	print("PROP FACTS props=%d mesh=%d orphans=%d" % [props, with_mesh, orphans.size()])
	print("PROP FACTS uses buildings=%d parts=%d parts_without_mesh=%d species=%d species_without_mesh=%d shots_with_mesh=%d" % [
		parts[0], parts[1], parts[2], species[0], species[1], shots])
	for line in notes:
		print("PROP FACTS   " + line)
	var ok: bool = props > 0 and with_mesh == props and orphans.is_empty() and parts[1] > 0 and parts[2] == 0 and species[0] > 0 and species[1] == 0
	return {"prop_facts": {"ok": ok, "props": props, "mesh": with_mesh, "orphans": orphans.size(), "notes": notes}}


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)


## [scenes, parts, parts without a mesh] of the building scenes: every MeshInstance3D under a holder of `Visuals`.
func _building_parts(notes: PackedStringArray) -> Array:
	var scenes := 0
	var parts := 0
	var empty := 0
	for file in DirAccess.get_files_at(BUILDINGS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var packed := load(BUILDINGS_DIR + file) as PackedScene
		var root := packed.instantiate() if packed != null else null
		if root == null:
			_note(notes, "%s does not instantiate" % file)
			continue
		scenes += 1
		for node in root.find_children("*", "MeshInstance3D", true, false):
			parts += 1
			if (node as MeshInstance3D).mesh == null:
				empty += 1
				_note(notes, "%s: %s has no mesh" % [file, root.get_path_to(node)])
		root.free()
	return [scenes, parts, empty]


## [files, files without `mesh`] of the .tres in `dir`.
func _resources_with_mesh(dir: String, notes: PackedStringArray) -> Array:
	var total := 0
	var empty := 0
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tres"):
			continue
		total += 1
		var resource := load(dir + file)
		if resource == null or resource.get("mesh") == null:
			empty += 1
			_note(notes, "%s: no mesh" % file)
	return [total, empty]


## The shot looks that draw a mesh (the others fly as a ball): all of them must load.
func _shots(notes: PackedStringArray) -> int:
	var with_mesh := 0
	for file in DirAccess.get_files_at(SHOTS_DIR):
		if file.ends_with(".tres"):
			var look := load(SHOTS_DIR + file) as ShotLook
			if look == null:
				_note(notes, "%s is not a ShotLook" % file)
			elif look.mesh != null:
				with_mesh += 1
	return with_mesh


## The meshes of `names` that no .tscn or .tres of scenes/ and data/ mentions (the libraries of clips are skipped: no mesh there).
func _orphans(names: PackedStringArray) -> PackedStringArray:
	var used := {}
	for dir in SCAN_DIRS:
		_scan(dir, used)
	var out := PackedStringArray()
	for file in names:
		if not used.has(MESHES_DIR + file):
			out.append(file)
	return out


func _scan(dir: String, used: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.ends_with("_clips") and not sub.begins_with("."):
			_scan(dir + sub + "/", used)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn") or file.ends_with(".tres"):
			var text := FileAccess.get_file_as_string(dir + file)
			var from := text.find(MESHES_DIR)
			while from >= 0:
				var to := text.find(".res", from)
				if to < 0:
					break
				used[text.substr(from, to + 4 - from)] = true
				from = text.find(MESHES_DIR, to)
