extends Node

## No necesita el juego original; usa los modelos y datos ya importados en assets/original (versionados).
## Every model a map draws has a baked asset. Enters the active map's scene (`--map=<tag>` after `--`, High Noon without it)
## as check_map_starts does, then for each BodyVisual under it (building parts, plants, founts, start previews):
## the model is in BodyCatalog (a BodySize, so the server shapes its box), and it has a mesh: a skeletal body scene, or
## assets/original/props/<model>.glb with a mesh whose every surface gets a texture from OriginalMaterial.
## That is what MapBuilding's "sin modelo horneado" warning reports, checked here headless, where the warning is never
## printed (BodyCatalog.loads_meshes() is false without a display). Prints MAP MODELS PASS / MAP MODELS FAIL; exit 0 / 1.
## "$GODOT" --headless --path game res://tools/audit/check_map_models.tscn -- --map=peaks


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := MapCatalog.active()
	var packed := map.load_scene()
	var root := packed.instantiate() if packed else null
	if root == null:
		_finish(map, 0, ["%s does not load" % map.map_scene_path])
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
	var problems: Array[String] = []
	var tags := models.keys()
	tags.sort()
	for model: String in tags:
		var why: String = _missing(model)
		if not why.is_empty():
			problems.append("%s: %s (used by %s)" % [model, why, ", ".join(models[model])])
	root.queue_free()
	_finish(map, tags.size(), problems)


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
