@tool
class_name BodyCatalog
extends RefCounted

## Bodies and props: sizes, pose and meshes by model tag.
## Sizes come from the BodySize .tres of data/catalog/body_sizes/ (GameCatalog, baked by tools/bake/bake_catalog.gd), static meshes (props, and the hybrid bodies
## that no clip animates) are the .glb of assets/original/props/ (RFC-033 033c, RFC-023 023h). Animated bodies are drawn by
## a BodyRig from assets/original/models/ and have no mesh here.
## On top of them go the hand corrections in data/bodies/pose_overrides.tres (turn, offset,
## scale, capsule). Nothing else corrects a pose: the baked sizes are never edited for a pose.
## Static and @tool: the editor has no autoloads, so BodyVisual reads the assets through here.
## The headless server reads sizes only, never a mesh.

const OVERRIDES_PATH := "res://data/bodies/pose_overrides.tres"

static var _loaded := false
static var _bodies: Dictionary = {}
static var _props: Dictionary = {}
static var _meshes: Dictionary = {}
static var _overrides: BodyPoseOverrides
static var _infos: Dictionary = {}


## Forgets everything read so far. Call after importing again.
## Not named reload(): that is Script.reload() and a static call would hit it instead.
static func refresh() -> void:
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


## True when `model` has a baked scene (scenes/bodies/models/<tag>.tscn): its bodies are drawn by a BodyRig. A model
## whose clips do not include the one it rests on (the hybrids) has no scene and stays a static mesh.
static func has_skeletal(model: String) -> bool:
	return BodyModel.exists(model)


static func has_model(model: String) -> bool:
	_ensure()
	return _bodies.has(model) or _props.has(model)


## Measures (BodySize) plus the capsule corrections: height, height_flying, radius and reach are final.
## A scale in the override scales the measured capsule too; capsule_* replaces it.
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


## The baked measures of `model` before any pose correction ({} when unknown): box, foot_offset, height, radius, reach, upright_fix.
static func measured(model: String) -> Dictionary:
	_ensure()
	return _bodies.get(model, _props.get(model, {}))


## Bodies first, then props, in the order of the catalog.
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


## The static mesh of a prop or a hybrid body; null for a body that a BodyRig draws (it has no static mesh).
static func mesh(model: String) -> Mesh:
	if not loads_meshes() or model.is_empty():
		return null
	if _meshes.has(model):
		return _meshes[model]
	var loaded := _prop_mesh(model)
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


## Local transform that stands the static mesh upright with its origin on the ground.
## Bodies measured from an idle frame need no lift (foot_offset 0); bind-pose bodies lift by it.
## Buildings and plants keep the sacengine origin (stand_on_feet off). The override goes on top.
## `skeletal`: a BodyRig draws the body (RFC-023 023c). A body measured from the bind pose (no pose_source: the
## peasants, Zyzyx) was measured turned upright and lifted by foot_offset to stand; its clips already stand on the ground, so the
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
	var catalog := GameCatalog.shared()
	if catalog == null:
		return
	for size in catalog.body_sizes:
		(_props if size.is_prop else _bodies)[size.tag] = size.to_record()


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
