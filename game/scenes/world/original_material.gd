class_name OriginalMaterial
extends RefCounted

## RFC-033 (033b): the one place that builds the material of a model from the original game.
## One StandardMaterial3D per texture file, shared by every mesh and clip frame that uses it.
## Textures are the PNGs of assets/original/textures/ (importer: tools/import_textures.py), with the colour key
## already in the alpha channel; textures/index.json says which texture each model's material label uses and
## whether it has transparent texels (cutout).
## A material is never edited after it is built: do not mutate what these functions return.

const ROUGHNESS := 0.85
const ALPHA_SCISSOR_THRESHOLD := 0.4

## texture path (and cutout) -> StandardMaterial3D
static var _materials: Dictionary = {}
## model (lower case) -> label -> {owner, file, cutout}; loaded once from OriginalAssets.texture_index()
static var _index: Dictionary = {}
static var _index_loaded := false


## "bodypartNNN" label of the OBJ (and glTF) surface that uses texture NNN.
static func part_label(part: int) -> String:
	return "bodypart%03d" % (part + 1)


## The model a mesh file belongs to: <model>/<model>.obj (bodies, buildings), <name>.obj (plants) or
## anim_f37/<model>/<clip>/N.obj (clip frames).
static func model_of(obj_path: String) -> String:
	var dirs := obj_path.get_base_dir().split("/")
	var at := dirs.find("anim_f37")
	if at >= 0 and at + 1 < dirs.size():
		return dirs[at + 1]
	return obj_path.get_file().get_basename()


## The material of a surface by its OBJ material label ("bodypart003", "M000", "plant"). Null when the model has no
## texture for that label (the surface stays untextured, like before).
static func for_label(model: String, label: String) -> StandardMaterial3D:
	var entry := _entry(model, label)
	if entry.is_empty():
		return null
	var path := OriginalAssets.texture(str(entry["owner"]), str(entry["file"]))
	var cutout := bool(entry["cutout"])
	var key := "%s|%s" % [path, cutout]
	if _materials.has(key):
		return _materials[key]
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("OriginalMaterial: missing texture %s (%s / %s); run tools/import_textures.py" % [path, model, label])
		return null
	var built := for_texture(tex, cutout, label)
	_materials[key] = built
	return built


## The material of surface `part` of a skeletal model (.glb): surface i is the model's body part i (see apply_to for merged surfaces).
static func for_part(model: String, part: int) -> StandardMaterial3D:
	return for_label(model, part_label(part))


## A new material over an already loaded texture. Use for_label()/for_part() to get the shared one.
static func for_texture(tex: Texture2D, cutout: bool, label: String = "") -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = label
	mat.albedo_texture = tex
	mat.roughness = ROUGHNESS
	if cutout:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = ALPHA_SCISSOR_THRESHOLD
	return mat


## Puts the shared materials on every surface of the meshes under `root` (a model's .glb scene, which has none).
## `surface_parts` (models/index.json): the body parts each surface merges (parts with one texture are one surface); the
## material is the one of its first part. Empty: surface i is body part i.
static func apply_to(root: Node, model: String, surface_parts: Array = []) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for i in instance.mesh.get_surface_count():
			var part := int((surface_parts[i] as Array)[0]) if i < surface_parts.size() else i
			var mat := for_part(model, part)
			if mat != null:
				instance.set_surface_override_material(i, mat)


static func _entry(model: String, label: String) -> Dictionary:
	if not _index_loaded:
		_index_loaded = true
		var path := OriginalAssets.texture_index()
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_index = (parsed as Dictionary).get("models", {})
	var labels: Dictionary = _index.get(model.to_lower(), {})
	return labels.get(label, {})
