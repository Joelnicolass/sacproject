@tool
class_name BodyCatalog
extends RefCounted

## Bodies and props: sizes, pose and meshes by model tag.
## Sizes come from assets/original/models/sizes.json (tools/import_props.py), props are the .glb of
## assets/original/props/ (RFC-033 033c), bodies are still the meshes baked by tools/bake_bodies.gd until RFC-023.
## On top of them go the hand corrections in data/bodies/pose_overrides.tres (turn, offset,
## scale, capsule). Nothing else corrects a pose: the sizes JSON is never edited by hand.
## Static and @tool: the editor has no autoloads, so BodyVisual reads the assets through here.
## The headless server reads sizes only, never a mesh.

## Baked body meshes (bodies/<m>.res) and clip frames: only until RFC-023 / 033i.
const BAKED_DIR := "res://cache/baked/"
## Clip frames baked by tools/bake_clips.gd (RFC-027 027h): one geometry .res per frame OBJ, same relative path.
const CLIPS_SUBDIR := "clips/"
const LOOK_DIR := "res://cache/look/"
const OVERRIDES_PATH := "res://data/bodies/pose_overrides.tres"

## Models whose skeleton did not close against the original frame by frame (tools/audit_skeletal.gd, RFC-023 023c): they
## keep the baked per-frame meshes. Empty while every exported model closes; the list is in the RFC's 023c result.
const SKELETAL_FALLBACK: PackedStringArray = []

## -1 unknown, 0 off, 1 on: the `--baked-bodies` user argument.
static var _baked_forced := -1
static var _dir := BAKED_DIR
static var _loaded := false
static var _bodies: Dictionary = {}
static var _props: Dictionary = {}
static var _meshes: Dictionary = {}
static var _overrides: BodyPoseOverrides
static var _infos: Dictionary = {}


## Forgets everything read so far. Call after baking again, or to point at another folder.
## Not named reload(): that is Script.reload() and a static call would hit it instead.
static func refresh(dir := BAKED_DIR) -> void:
	_dir = dir if dir.ends_with("/") else dir + "/"
	_loaded = false
	_bodies = {}
	_props = {}
	_meshes = {}
	_infos = {}
	_forget_overrides()


## The corrections in data/bodies/pose_overrides.tres, never null.
## Emits `changed` when an entry is edited. After refresh() this is a new read, so listeners
## must ask for it again and connect to the new one.
static func overrides() -> BodyPoseOverrides:
	if _overrides == null:
		var loaded: Resource = null
		if ResourceLoader.exists(OVERRIDES_PATH):
			loaded = ResourceLoader.load(OVERRIDES_PATH)
		_overrides = loaded as BodyPoseOverrides
		if _overrides == null:
			_overrides = BodyPoseOverrides.new()
		_overrides.changed.connect(_on_overrides_changed)
	return _overrides


## The editor always shows meshes; a headless run (the dedicated server) never loads them.
static func loads_meshes() -> bool:
	return Engine.is_editor_hint() or DisplayServer.get_name() != "headless"


## True when `model` has a skeletal asset (models/index.json) that is not in SKELETAL_FALLBACK: its bodies are drawn by a
## BodyRig. A model with no clip of its own still stays baked: the caller also checks it has the clip it rests on.
static func has_skeletal(model: String) -> bool:
	return not model.is_empty() and not baked_bodies_forced() and not SKELETAL_FALLBACK.has(model) \
		and not BodyRig.model_info(model).is_empty()


## The `--baked-bodies` user argument draws every body from the baked per-frame meshes, as before RFC-023: to compare the
## two looks and to measure the old cost in the same build. Until RFC-023h retires the baked meshes.
static func baked_bodies_forced() -> bool:
	if _baked_forced < 0:
		_baked_forced = 1 if OS.get_cmdline_user_args().has("--baked-bodies") else 0
	return _baked_forced == 1


static func has_model(model: String) -> bool:
	_ensure()
	return _bodies.has(model) or _props.has(model)


## Baked measures plus the capsule corrections: height, height_flying, radius and reach are final.
## A scale in the override scales the baked capsule too; capsule_* replaces it.
static func info(model: String) -> Dictionary:
	_ensure()
	if _infos.has(model):
		return _infos[model]
	var data: Dictionary = _bodies.get(model, _props.get(model, {}))
	var entry := overrides().find(model)
	if not data.is_empty():
		data = data.duplicate()
	if entry and not data.is_empty():
		var wide := maxf(absf(entry.model_scale.x), absf(entry.model_scale.z))
		data["height"] = entry.capsule_height if entry.capsule_height > 0.0 else float(data.get("height", 0.0)) * absf(entry.model_scale.y)
		data["radius"] = entry.capsule_radius if entry.capsule_radius > 0.0 else float(data.get("radius", 0.0)) * wide
		data["reach"] = entry.reach if entry.reach > 0.0 else float(data.get("reach", 0.0)) * wide
	if not data.is_empty():
		## F135: the capsule height of a hybrid flier while it flies (Flight); the ground one without an override.
		var flying := entry.capsule_height_flying if entry else 0.0
		data["height_flying"] = flying if flying > 0.0 else float(data.get("height", 0.0))
	_infos[model] = data
	return data


## Bodies first, then props, in the order of the baked files.
static func models() -> PackedStringArray:
	_ensure()
	var out := PackedStringArray()
	for tag: Variant in _bodies.keys():
		out.append(str(tag))
	for tag: Variant in _props.keys():
		var model := str(tag)
		if not out.has(model):
			out.append(model)
	return out


static func mesh(model: String) -> Mesh:
	if not loads_meshes() or model.is_empty():
		return null
	_ensure()
	if _meshes.has(model):
		return _meshes[model]
	var loaded: Mesh = null
	if _bodies.has(model):
		var path := _dir + "bodies/%s.res" % model
		if ResourceLoader.exists(path):
			loaded = ResourceLoader.load(path) as Mesh
	else:
		loaded = _prop_mesh(model)
	_meshes[model] = loaded
	return loaded


## The mesh of props/<model>.glb with the shared materials of OriginalMaterial on its surfaces (named after the
## material label of the original). One mesh per model, shared by every instance: the resource cache keeps the
## loaded scene's mesh, so the materials are set once.
static func _prop_mesh(model: String) -> Mesh:
	var path := OriginalAssets.prop(model)
	if not ResourceLoader.exists(path):
		return null
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var holder: MeshInstance3D = root as MeshInstance3D
	if holder == null:
		holder = root.find_child("*", true, false) as MeshInstance3D
	var found: Mesh = holder.mesh if holder else null
	root.free()
	if found == null:
		return null
	for i in found.get_surface_count():
		found.surface_set_material(i, OriginalMaterial.for_label(model, found.surface_get_name(i)))
	return found


## Where tools/bake_clips.gd leaves the baked frame of a clip OBJ (res://cache/look/X.obj -> <baked>/clips/X.res).
## Empty for a path outside cache/look/. Only a path: the file may not exist (cache not baked yet).
static func clip_frame_path(obj_path: String) -> String:
	if not obj_path.begins_with(LOOK_DIR):
		return ""
	return _dir + CLIPS_SUBDIR + obj_path.trim_prefix(LOOK_DIR).get_basename() + ".res"


## Local transform that stands the baked mesh upright with its origin on the ground.
## Bodies baked from an idle frame need no lift (foot_offset 0); older bind-pose bodies lift by it.
## Buildings and plants keep the sacengine origin (stand_on_feet off). The override goes on top.
## `skeletal`: a BodyRig draws the body (RFC-023 023c). A body that was baked from the bind pose (no pose_source: the
## peasants, Zyzyx) was turned upright and lifted by foot_offset to stand; its clips already stand on the ground, so the
## skeleton does not take either. Only the hand overrides apply.
static func pose(model: String, stand_on_feet := true, skeletal := false) -> Transform3D:
	var data := info(model)
	var bind_fix := not (skeletal and str(data.get("pose_source", "")).is_empty())
	var turn := _vector(data.get("upright_fix"), Vector3.ZERO) if bind_fix else Vector3.ZERO
	var at := Vector3.ZERO
	var size := Vector3.ONE
	var entry := overrides().find(model)
	if entry:
		turn += entry.rotation_degrees
		at = entry.position_offset
		size = entry.model_scale
	if stand_on_feet and bind_fix:
		at.y += float(data.get("foot_offset", 0.0))
	var radians := Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))
	return Transform3D(Basis.from_euler(radians) * Basis.from_scale(size), at)


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var sizes := _read_json(OriginalAssets.sizes())
	_bodies = sizes.get("bodies", {})
	_props = sizes.get("props", {})


static func _on_overrides_changed() -> void:
	_infos = {}


static func _forget_overrides() -> void:
	if _overrides and _overrides.changed.is_connected(_on_overrides_changed):
		_overrides.changed.disconnect(_on_overrides_changed)
	_overrides = null


static func _vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
