extends SceneTree

## RFC-033 parity audit: what the game loads from assets/original/ equals what it built from cache/ before.
## Deleted in 033i, together with cache/.
##   bash agent/harness/godot_run.sh "$GODOT" --headless --path game --script res://tools/audit_original_assets.gd
## 033b, textures: for every (model, label) of textures/index.json the imported texture (all mipmap levels) must be
## byte-identical to the old runtime pipeline: source file (TGA or PNG), colour key of the limb record, alpha edges,
## mipmaps. Exits 1 on any mismatch.
## The colour key was applied at runtime only where the OBJ sat beside its SAXS (bind-pose bodies, not clip frames), so
## the PNG of a model with clips differs from what its frames showed before. That is reported, not failed: "chroma".

const BODIES := "res://cache/look/bodies/"
const ANIM := "res://cache/look/anim_f37/"
const CATALOG := "res://cache/look/persephone/catalog.json"

var _failed := 0
var _checked := 0


func _initialize() -> void:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OriginalAssets.texture_index())).get("models", {})
	var body_dirs := _body_dirs()
	var clip_models := _dir_names(ANIM)
	var props := _prop_sources()
	var chroma := {}
	var cutouts := 0
	var tail_rounding := 0
	for model: String in index:
		for label: String in index[model]:
			var entry: Dictionary = index[model][label]
			var keyed := false
			var source := ""
			var key := -1
			if body_dirs.has(model) and label.begins_with("bodypart"):
				var folder: String = BODIES + str(body_dirs[model]) + "/"
				source = folder + label.trim_prefix("bodypart") + ".tga"
				key = _chroma_keys(folder + str(body_dirs[model]) + ".SAXS").get(label, -1)
			else:
				source = str(props.get("%s|%s" % [model, label], ""))
			if source.is_empty() or not FileAccess.file_exists(source):
				_fail("%s/%s: source missing (%s)" % [model, label, source])
				continue
			var old := _old_pipeline(source, key)
			var plain := _old_pipeline(source, -1)
			var cutout: bool = old[1]
			cutouts += 1 if cutout else 0
			if cutout != bool(entry["cutout"]):
				_fail("%s/%s: cutout flag %s, old pipeline %s" % [model, label, entry["cutout"], cutout])
			var path := OriginalAssets.texture(str(entry["owner"]), str(entry["file"]))
			var tex := load(path) as Texture2D
			if tex == null:
				_fail("%s/%s: cannot load %s" % [model, label, path])
				continue
			var got := tex.get_image()
			got.convert(Image.FORMAT_RGBA8)
			var want: Image = old[0]
			_checked += 1
			var verdict := _compare(got, want)
			if not verdict.is_empty():
				_fail("%s/%s: %s (%s)" % [model, label, verdict, path])
			elif got.get_data() != want.get_data():
				tail_rounding += 1
			if key >= 0 and clip_models.has(model) and (old[0] as Image).get_data() != (plain[0] as Image).get_data():
				chroma[model] = int(chroma.get(model, 0)) + 1
	# ObjMesh + OriginalMaterial end to end: surfaces named after their label, textured, shared per texture.
	var obj = load("res://scenes/world/obj_mesh.gd")
	for path: String in ["res://cache/look/bodies/eorc/eorc.obj", "res://cache/look/buildings/bld1/bld1.obj", "res://cache/look/persephone/plants/PCF1.obj"]:
		var mesh: ArrayMesh = obj.build(path, {})
		if mesh == null or mesh.get_surface_count() == 0:
			_fail("ObjMesh.build %s: no mesh" % path)
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null or mat.albedo_texture == null or mesh.surface_get_name(i).is_empty():
				_fail("ObjMesh.build %s surface %d: no material or name" % [path, i])
	var a := OriginalMaterial.for_label("eorc", "bodypart001")
	if a == null or a != OriginalMaterial.for_part("eorc", 0) or a != OriginalMaterial.for_label("EORC", "bodypart001"):
		_fail("OriginalMaterial is not shared per texture")
	print("audit_original_assets: %d textures checked, %d with alpha, %d failed, %d with a +-1 alpha rounding in a small mip" % [_checked, cutouts, _failed, tail_rounding])
	var names := chroma.keys()
	names.sort()
	var changed := 0
	for m: String in names:
		changed += int(chroma[m])
	print("chroma: %d labels of %d models with clips draw differently from their old (un-keyed) frames: %s" % [changed, names.size(), ", ".join(names)])
	quit(1 if _failed > 0 else 0)


func _fail(message: String) -> void:
	_failed += 1
	if _failed <= 40:
		print("FAIL ", message)


## "" when `got` equals `want` at every mipmap level, else what differs. The importer rounds the averaged ALPHA of the
## smallest mips differently from Image.generate_mipmaps(): off by one in the alpha byte of a level above 0. Allowed
## (colour and level 0 must be exact).
func _compare(got: Image, want: Image) -> String:
	if got.get_size() != want.get_size() or got.get_mipmap_count() != want.get_mipmap_count():
		return "size or mip count differs (%s/%d vs %s/%d)" % [got.get_size(), got.get_mipmap_count(), want.get_size(), want.get_mipmap_count()]
	var a := got.get_data()
	var b := want.get_data()
	var w := want.get_width()
	var h := want.get_height()
	var off := 0
	for level in want.get_mipmap_count() + 1:
		var size := w * h * 4
		for i in size:
			var tolerance := 1 if level > 0 and i % 4 == 3 else 0
			if absi(int(a[off + i]) - int(b[off + i])) > tolerance:
				return "level %d (%dx%d) differs at byte %d: %d vs %d" % [level, w, h, i, a[off + i], b[off + i]]
		off += size
		w = maxi(1, w / 2)
		h = maxi(1, h / 2)
	return ""


## [Image (RGBA8, edges fixed, mipmapped), cutout] exactly as ObjMesh._build_material did.
func _old_pipeline(path: String, key: int) -> Array:
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return [Image.new(), false]
	if image.is_compressed():
		image.decompress()
	if key >= 0:
		image.convert(Image.FORMAT_RGBA8)
		var data := image.get_data()
		var r := (key >> 16) & 0xff
		var g := (key >> 8) & 0xff
		var b := key & 0xff
		for i in range(0, data.size(), 4):
			if data[i] == r and data[i + 1] == g and data[i + 2] == b:
				data[i + 3] = 0
		image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
	var cutout := image.detect_alpha() != Image.ALPHA_NONE
	image.convert(Image.FORMAT_RGBA8)
	if cutout:
		image.fix_alpha_edges()
	image.generate_mipmaps()
	return [image, cutout]


func _chroma_keys(saxs: String) -> Dictionary:
	var keys := {}
	if not FileAccess.file_exists(saxs):
		return keys
	var raw := FileAccess.get_file_as_bytes(saxs)
	for limb in 16:
		var at := 0x58 + limb * 6
		if at + 6 > raw.size():
			break
		if raw[at] & 1:
			keys["bodypart%03d" % (limb + 1)] = raw.decode_u32(at + 2) & 0xffffff
	return keys


func _dir_names(root: String) -> Dictionary:
	var found := {}
	for name in DirAccess.get_directories_at(root):
		found[name.to_lower()] = name
	return found


func _body_dirs() -> Dictionary:
	return _dir_names(BODIES)


## "<prop lower>|<label>" -> source PNG, by the rule the old runtime used: beside the OBJ, else the catalog texture.
func _prop_sources() -> Dictionary:
	var found := {}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	for kind: String in ["structures", "plants"]:
		for item: Dictionary in catalog.get(kind, []):
			var obj := str(item["mesh"])
			var labels := PackedStringArray()
			for line in FileAccess.get_file_as_string(obj).split("\n"):
				if line.begins_with("usemtl "):
					var label := line.substr(7).strip_edges()
					if not labels.has(label):
						labels.append(label)
			for label in labels:
				var beside := obj.get_base_dir().path_join(label + ".png")
				found["%s|%s" % [str(item["name"]).to_lower(), label]] = beside if FileAccess.file_exists(beside) else str(item.get("texture", ""))
	return found
