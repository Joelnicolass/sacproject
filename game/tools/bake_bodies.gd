extends SceneTree

## Bakes the cached OBJ bodies, buildings and plants into .res meshes once.
## "$GODOT" --headless --path game --script res://tools/bake_bodies.gd

const _OBJ := preload("res://scenes/world/obj_mesh.gd")

const CATALOG := "res://cache/look/persephone/catalog.json"
const OUT := "res://cache/baked/"
const CLIPS := "res://cache/data/anim_mesh_clips_f37.json"
const CREATURES := "res://cache/data/creatures.json"
const WIZARDS := "res://cache/data/wizards.json"
const BOOKS := "res://cache/data/books.json"
## F112 (RFC-030a): book creatures from this wizard level up are baked from frame 0 of stance1, the rest pose
## sacengine plays between gestures (state.d:7957-7992). The ones below keep idle0 until RFC-023.
## Same value as STANCE_POSE_MIN_LEVEL in tools/export_stats.py, which exports those stance1 clips.
const STANCE_POSE_MIN_LEVEL := 2

## Models with an exported idle clip are baked from its frame 0: sacengine already stands them
## upright with the origin on the ground, so there is nothing to guess and nothing to lift.
## Only models without a clip fall back to the bind pose below, which can lie on its back
## (the head points to sac -y, OBJ +z). Such a body is lying when it is much longer than tall.
const LYING_RATIO := 1.6
## Manual corrections for bind-pose bodies, after looking at res://debug/body_gallery.tscn.
const FORCE_LYING: PackedStringArray = ["maho"]
## Winged bodies, longer than tall but already standing.
const FORCE_UPRIGHT: PackedStringArray = ["baby", "ddmn", "drag", "sirc"]


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	if not FileAccess.file_exists(CATALOG):
		push_error("Falta %s" % CATALOG)
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "bodies"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "props"))
	var bodies := {}
	var upright := 0
	var from_clip := 0
	var idle_frames := _idle_frames()
	for item: Dictionary in catalog.get("creatures", []):
		var model := str(item.get("name", ""))
		var frame := str(idle_frames.get(model, ""))
		var posed := not frame.is_empty() and FileAccess.file_exists(frame)
		var built := _OBJ.build(frame if posed else str(item.get("mesh", "")), "", {_OBJ.MIRROR_Z: true})
		if built == null:
			print("falta ", model)
			continue
		if posed:
			from_clip += 1
			upright += 1
			bodies[model] = _describe_posed(built)
			bodies[model]["pose_source"] = frame.get_base_dir().get_file()
		else:
			var fix := _upright_fix(model, built.get_aabb())
			if fix == Vector3.ZERO:
				upright += 1
			bodies[model] = _describe(built, fix)
			bodies[model]["upright_checked"] = FORCE_UPRIGHT.has(model) or FORCE_LYING.has(model)
		_save(built, OUT + "bodies/%s.res" % model)
	var props := {}
	for item: Dictionary in catalog.get("structures", []):
		var name := str(item.get("name", ""))
		var built := _OBJ.build(str(item.get("mesh", "")))
		if built:
			props[name] = _describe(built, Vector3.ZERO)
			_save(built, OUT + "props/%s.res" % name)
	var ground: PackedStringArray = []
	for item: Dictionary in catalog.get("plants", []):
		var name := str(item.get("name", ""))
		var mesh_path := str(item.get("mesh", ""))
		var built := _OBJ.build(mesh_path, str(item.get("texture", "")), {_OBJ.FOLIAGE: true})
		if built:
			props[name] = _describe(built, Vector3.ZERO)
			_save(built, OUT + "props/%s.res" % name)
			var parsed := _OBJ.parse(mesh_path)
			if not parsed.is_empty() and _OBJ.is_ground_widget(parsed["surfaces"]):
				ground.append(name)
	print("widgets de suelo: ", ", ".join(ground))
	_write_json(OUT + "bodies.json", bodies)
	_write_json(OUT + "props.json", props)
	print("horneado %d cuerpos (%d desde el idle, %d sin giro) %d props en %d ms" % [bodies.size(), from_clip, upright, props.size(), Time.get_ticks_msec() - started])
	quit()


## model -> frame 0 of its idle clip (res:// path), for the models that have one. Book creatures of level
## STANCE_POSE_MIN_LEVEL or more use their stance1 clip instead.
func _idle_frames() -> Dictionary:
	var clips := _read(CLIPS)
	var stance_tags := _stance_creatures()
	var found := {}
	for path: String in [CREATURES, WIZARDS]:
		var rows := _read(path)
		for tag: Variant in rows:
			var row: Dictionary = rows[tag]
			var model := str(row.get("model", ""))
			var key := "stance_animation" if path == CREATURES and stance_tags.has(str(tag)) else "idle_animation"
			var idle := str(row.get(key, {}).get("tag", ""))
			var frames: Array = clips.get(model, {}).get(idle, {}).get("frame_objs", [])
			if not model.is_empty() and not frames.is_empty() and not found.has(model):
				found[model] = str(frames[0])
	return found


## Creature tags whose lowest level in any book is STANCE_POSE_MIN_LEVEL or more.
func _stance_creatures() -> Dictionary:
	var lowest := {}
	var books := _read(BOOKS)
	for god: Variant in books:
		var levels: Dictionary = books[god].get("levels", {})
		for tag: Variant in levels:
			lowest[str(tag)] = mini(int(levels[tag]), int(lowest.get(str(tag), 99)))
	var result := {}
	for tag: String in lowest:
		if int(lowest[tag]) >= STANCE_POSE_MIN_LEVEL:
			result[tag] = true
	return result


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _upright_fix(model: String, box: AABB) -> Vector3:
	var lying := box.size.z > box.size.y * LYING_RATIO and box.size.z >= box.size.x
	if FORCE_LYING.has(model):
		lying = true
	if FORCE_UPRIGHT.has(model):
		lying = false
	# After the z mirror the head points to -z; +90 deg on X brings it up.
	return Vector3(90.0, 0.0, 0.0) if lying else Vector3.ZERO


## The box of the mesh as [x, y, z, width, height, depth], so a server without meshes (headless) can still shape the
## collision of a building (RFC-024 addendum 1, MapBuilding).
func _box_list(box: AABB) -> Array:
	return [snappedf(box.position.x, 0.001), snappedf(box.position.y, 0.001), snappedf(box.position.z, 0.001),
		snappedf(box.size.x, 0.001), snappedf(box.size.y, 0.001), snappedf(box.size.z, 0.001)]


func _describe(built: ArrayMesh, fix: Vector3) -> Dictionary:
	var turn := Basis.from_euler(fix * PI / 180.0)
	var box := Transform3D(turn, Vector3.ZERO) * built.get_aabb()
	return {
		"height": snappedf(box.size.y, 0.001),
		"foot_offset": snappedf(-box.position.y, 0.001),
		"radius": snappedf(maxf(minf(box.size.x, box.size.z) * 0.35, 0.2), 0.001),
		"reach": snappedf(maxf(box.size.x, box.size.z) * 0.5, 0.001),
		"upright_fix": [fix.x, fix.y, fix.z],
		"box": _box_list(box),
	}


## Capsule of a body baked from an idle frame: already upright, origin on the ground.
## The height counts from the origin up, so a clip that dips below the ground does not stretch it.
func _describe_posed(built: ArrayMesh) -> Dictionary:
	var box := built.get_aabb()
	return {
		"height": snappedf(maxf(box.end.y, 0.1), 0.001),
		"foot_offset": 0.0,
		"radius": snappedf(maxf(minf(box.size.x, box.size.z) * 0.35, 0.2), 0.001),
		"reach": snappedf(maxf(box.size.x, box.size.z) * 0.5, 0.001),
		"upright_fix": [0.0, 0.0, 0.0],
		"box": _box_list(box),
	}


func _save(built: ArrayMesh, path: String) -> void:
	var err := ResourceSaver.save(built, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [path, err])


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true))
