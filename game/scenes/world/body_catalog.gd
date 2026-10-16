@tool
class_name BodyCatalog
extends RefCounted

## Baked bodies and props from tools/bake_bodies.gd: sizes, pose and meshes by model tag.
## On top of them go the hand corrections in data/bodies/pose_overrides.tres (turn, offset,
## scale, capsule). Nothing else corrects a pose: the baked JSON is never edited by hand.
## Static and @tool: the editor has no autoloads, so BodyVisual reads the cache through here.
## The headless server reads sizes only.

const BAKED_DIR := "res://cache/baked/"
const OVERRIDES_PATH := "res://data/bodies/pose_overrides.tres"

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


static func has_model(model: String) -> bool:
	_ensure()
	return _bodies.has(model) or _props.has(model)


## Baked measures plus the capsule corrections: height, radius and reach are final.
## A scale in the override scales the baked capsule too; capsule_* replaces it.
static func info(model: String) -> Dictionary:
	_ensure()
	if _infos.has(model):
		return _infos[model]
	var data: Dictionary = _bodies.get(model, _props.get(model, {}))
	var entry := overrides().find(model)
	if entry and not data.is_empty():
		data = data.duplicate()
		var wide := maxf(absf(entry.model_scale.x), absf(entry.model_scale.z))
		data["height"] = entry.capsule_height if entry.capsule_height > 0.0 else float(data.get("height", 0.0)) * absf(entry.model_scale.y)
		data["radius"] = entry.capsule_radius if entry.capsule_radius > 0.0 else float(data.get("radius", 0.0)) * wide
		data["reach"] = entry.reach if entry.reach > 0.0 else float(data.get("reach", 0.0)) * wide
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
	var folder := "bodies" if _bodies.has(model) else "props"
	var path := _dir + "%s/%s.res" % [folder, model]
	var loaded: Mesh = null
	if ResourceLoader.exists(path):
		loaded = ResourceLoader.load(path) as Mesh
	_meshes[model] = loaded
	return loaded


## Local transform that stands the baked mesh upright with its origin on the ground.
## Bodies baked from an idle frame need no lift (foot_offset 0); older bind-pose bodies lift by it.
## Buildings and plants keep the sacengine origin (stand_on_feet off). The override goes on top.
static func pose(model: String, stand_on_feet := true) -> Transform3D:
	var data := info(model)
	var turn := _vector(data.get("upright_fix"), Vector3.ZERO)
	var at := Vector3.ZERO
	var size := Vector3.ONE
	var entry := overrides().find(model)
	if entry:
		turn += entry.rotation_degrees
		at = entry.position_offset
		size = entry.model_scale
	if stand_on_feet:
		at.y += float(data.get("foot_offset", 0.0))
	var radians := Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))
	return Transform3D(Basis.from_euler(radians) * Basis.from_scale(size), at)


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_bodies = _read_json(_dir + "bodies.json")
	_props = _read_json(_dir + "props.json")


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
