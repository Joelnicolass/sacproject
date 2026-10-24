extends Node

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## Every model a map draws has a baked asset. Enters the active map's scene (`--map=<tag>` after `--`, High Noon without it)
## as check_map_starts does, then for each BodyVisual under it (building parts, plants, founts, start previews):
## the model is in BodyCatalog (a BodySize, so the server shapes its box), and it has a mesh: a skeletal body scene, or
## assets/original/props/<model>.glb with a mesh whose every surface gets a texture from OriginalMaterial.
## That is what MapBuilding's "sin modelo horneado" warning reports, checked here headless, where the warning is never
## printed (BodyCatalog.loads_meshes() is false without a display). Prints MAP MODELS PASS / MAP MODELS FAIL; exit 0 / 1.
## Every manafount draws its land's model: the BASE component of the BLDG of the NTTS fount row at its spot (jfnt, cafn, pfon,
## stmf; font = pcfn), and ManafountBody.FALLBACK_MODEL on a map without an NTTS (test_flat).
## "$GODOT" --headless --path game res://tools/audit/check_map_models.tscn -- --map=peaks

## The manafount of each land (BuildingType flags 0x80002810), same list as tools/import/scaffold_map.py.
const FOUNT_TAGS: PackedStringArray = ["jfnt", "cafn", "pfon", "stmf", "font"]
## A fount node and its NTTS row are the same spot (scaffold_map places one on the other).
const FOUNT_ROW_MAX_M := 1.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := MapCatalog.active()
	var packed := map.map_scene
	var root := packed.instantiate() if packed else null
	if root == null:
		_finish(map, 0, ["the scene of '%s' does not load" % map.tag])
		return
	add_child(root)
	await get_tree().physics_frame
	var models := {}
	for node in root.find_children("*", "", true, false):
		var visual := node as BodyVisual
		if visual != null and not visual.model.is_empty():
			var users: Array = models.get(visual.model, [])
			if users.size() < 3:
				users.append(str(root.get_path_to(visual)))
			models[visual.model] = users
	var problems: Array[String] = _fount_problems(map, root)
	var tags := models.keys()
	tags.sort()
	for model: String in tags:
		var why: String = _missing(model)
		if not why.is_empty():
			problems.append("%s: %s (used by %s)" % [model, why, ", ".join(models[model])])
	root.queue_free()
	_finish(map, tags.size(), problems)


## Each ManafountBody shows the model its NTTS row's BLDG names (FALLBACK_MODEL without an NTTS); one line per mismatch.
func _fount_problems(map: MapDefinition, root: Node) -> Array[String]:
	var rows: Array = []
	var ntts_path := OriginalAssets.map(String(map.tag), "ntts.json")
	if FileAccess.file_exists(ntts_path):
		var ntts: Variant = JSON.parse_string(FileAccess.get_file_as_string(ntts_path))
		if not ntts is Dictionary:
			return ["%s does not parse" % ntts_path]
		for row: Dictionary in (ntts as Dictionary).get("structures", []):
			if FOUNT_TAGS.has(str(row.get("tag", ""))):
				rows.append(row)
	var problems: Array[String] = []
	var counted := 0
	for node in root.find_children("*", "", true, false):
		var fount := node as ManafountBody
		if fount == null:
			continue
		counted += 1
		var shown := fount.visual.model if fount.visual != null else ""
		var expected := ManafountBody.FALLBACK_MODEL
		if not rows.is_empty():
			var at := Vector2(fount.global_position.x, fount.global_position.z)
			var best: Dictionary = {}
			for row: Dictionary in rows:
				if best.is_empty() or at.distance_to(_row_xz(row)) < at.distance_to(_row_xz(best)):
					best = row
			if at.distance_to(_row_xz(best)) > FOUNT_ROW_MAX_M:
				problems.append("fount %s: no NTTS fount row at its spot" % root.get_path_to(fount))
				continue
			expected = _base_model(TypeRef.building(str(best["tag"])))
		if shown != expected:
			problems.append("fount %s: shows '%s', its land's fountain is '%s'" % [root.get_path_to(fount), shown, expected])
	if counted == 0:
		problems.append("fount count: the scene has no ManafountBody")
	elif not rows.is_empty() and counted != rows.size():
		problems.append("fount count: %d in the scene, %d rows in %s" % [counted, rows.size(), ntts_path])
	print("%s founts: %d checked" % [map.tag, counted])
	return problems


func _row_xz(row: Dictionary) -> Vector2:
	return Vector2(float(row["x"]), float(row["z"]))


## The BASE component of a BLDG (what ManafountBody.model() draws), FALLBACK_MODEL when it has none.
func _base_model(building: BuildingType) -> String:
	var base := building.base_model() if building != null else ""
	return base if not base.is_empty() else ManafountBody.FALLBACK_MODEL


## Why `model` would show the placeholder (or an untextured mesh); "" when it has everything.
func _missing(model: String) -> String:
	if not BodyCatalog.has_model(model):
		return "no BodySize in data/catalog/body_sizes"
	if BodyCatalog.has_skeletal(model):
		return ""
	var path := OriginalAssets.prop(model)
	if not ResourceLoader.exists(path):
		return "no %s" % path
	var scene := load(path) as PackedScene
	var top := scene.instantiate() if scene else null
	if top == null:
		return "%s does not instantiate" % path
	var holder := top as MeshInstance3D
	if holder == null:
		holder = top.find_child("*", true, false) as MeshInstance3D
	var mesh: Mesh = holder.mesh if holder else null
	var why := ""
	if mesh == null or mesh.get_surface_count() == 0:
		why = "%s has no mesh" % path
	else:
		for i in mesh.get_surface_count():
			var label: String = mesh.surface_get_name(i)
			if OriginalMaterial.for_label(model, label) == null:
				why = "no texture for surface '%s' in textures/index.json" % label
				break
	top.free()
	return why


func _finish(map: MapDefinition, count: int, problems: Array[String]) -> void:
	for line in problems:
		print("missing model on %s: %s" % [map.tag, line])
	print("%s %s: %d models, %d without an asset" % [
		"MAP MODELS PASS" if problems.is_empty() else "MAP MODELS FAIL", map.tag, count, problems.size()])
	get_tree().quit(0 if problems.is_empty() else 1)
