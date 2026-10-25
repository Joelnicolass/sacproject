class_name BodyFacts
extends RefCounted

## The size and sockets of a body that the rules need (how tall, how wide, how far its blow reaches, where its hand and center are),
## read once from its BodyFrame scene and kept. A creature or wizard asks its BodyMount for them; nothing loads a scene or searches
## a node per frame. The measures (height, radius, reach, flying height) are decoded to the mm (_mm): the scene keeps 32 bits and the
## rules read them as doubles, which today come from text with at most 3 decimals. Capsules and sockets stay 32-bit (a shape, a Vector3).
## What it does not do: move a body, size a physics shape (BodyCollider) or choose which scene a body wears (BodyMount).

## Fraction of the height where a thrown ball leaves the hand when the scene has no `muzzle` marker.
const _HAND_FRACTION := 0.65

## One BodyFacts per body scene, built the first time somebody asks.
static var _cache: Dictionary[PackedScene, BodyFacts] = {}
static var _model_cache: Dictionary[String, BodyFacts] = {}
## What a body that wears nothing reads: the size of an unknown model.
static var _fallback: BodyFacts

var model_id := ""
## The real height of the body (the cylinder of the footprint), before the capsule floor of 0.6 m.
var height_m := 1.8
## The height while a hybrid flier is up; the ground one for any other body.
var flying_height_m := 1.8
## Half the width of the footprint: the radius other bodies keep away from.
var radius_m := 0.35
## How far in front of the body its blow reaches.
var reach_m := 0.35
## The physics capsule: height and radius on the ground, and its height in the air.
var capsule_height_m := 1.8
var capsule_radius_m := 0.35
var flying_capsule_height_m := 1.8
## Local positions of the sockets (the origin of the body is at its feet).
var muzzle := Vector3.ZERO
var center := Vector3(0.0, 0.9, 0.0)
var top := Vector3(0.0, 1.8, 0.0)
var feet := Vector3.ZERO
## True when the facts come from a scene (false for the unknown-model default).
var from_scene := false


func _init() -> void:
	muzzle = _hand(height_m, reach_m)


## The facts of the body scene `scene` (built once and shared). The unknown-model default for null or an incomplete frame.
## A dictionary lookup after the first call, never a load: safe per tick. Read from the scene's SceneState, never instantiated:
## a BodyFrame instance creates physics objects (its Bounds Area3D) even outside the tree, and that alone moves the simulation.
static func of(scene: PackedScene) -> BodyFacts:
	if scene == null:
		return fallback()
	if not _cache.has(scene):
		var built := BodyFacts.new()
		_cache[scene] = built if built._read(scene.get_state()) else fallback()
	return _cache[scene]


## The facts of the body scene `body` wears (a UnitBody, WizardBody or DoctorBody has a `mount`). Anything else with a
## `model` (a building, a structure a blow aims at) keeps the baked size of that model until 055s s5a/s5b give props their
## own facts; the default when there is neither.
static func of_body(body: Object) -> BodyFacts:
	var found: Variant = body.get("mount") if body != null and "mount" in body else null
	var mount := found as BodyMount
	if mount != null:
		return mount.facts
	if body != null and "model" in body:
		return _of_model(str(body.get("model")))
	return fallback()


## A prop's size from BodyCatalog (doubles from the .tres, as the rules read them before 055s). Built once per model.
static func _of_model(model: String) -> BodyFacts:
	if model.is_empty():
		return fallback()
	if not _model_cache.has(model):
		var info := BodyCatalog.info(model)
		var built := BodyFacts.new()
		built.height_m = float(info.get("height", 1.8))
		built.flying_height_m = built.height_m
		built.radius_m = float(info.get("radius", 0.35))
		built.reach_m = float(info.get("reach", 0.35))
		built.muzzle = _hand(built.height_m, built.reach_m)
		_model_cache[model] = built
	return _model_cache[model]


## The size of a body with no scene: 1.8 m tall, 0.35 m wide, 0.35 m of reach.
static func fallback() -> BodyFacts:
	if _fallback == null:
		_fallback = BodyFacts.new()
	return _fallback


## Half the width of the box: the larger of the footprint radius and the reach.
func half_size_m() -> float:
	return maxf(radius_m, reach_m)


## Fills these facts from the saved BodyFrame `state` (its node paths, shapes and marker positions). False when a node the
## rules need is missing (the same as BodyFrame.is_complete()).
func _read(state: SceneState) -> bool:
	var nodes := {}
	for index in state.get_node_count():
		var props := {}
		for slot in state.get_node_property_count(index):
			props[String(state.get_node_property_name(index, slot))] = state.get_node_property_value(index, slot)
		## A PackedScene state names the root "." and its children "./Child".
		nodes[String(state.get_node_path(index)).trim_prefix("./")] = props
	var root: Dictionary = nodes.get(".", {})
	var footprint := _shape(nodes, root, "footprint") as CylinderShape3D
	var ground := _shape(nodes, root, "capsule") as CapsuleShape3D
	var air_path: Variant = root.get("flying_capsule")
	var air := _shape(nodes, root, "flying_capsule") as CapsuleShape3D
	var marks: Array[String] = ["reach", "center", "top"]
	for mark: String in marks:
		if not root.has(mark) or not nodes.has(String(root[mark])):
			return false
	if footprint == null or ground == null or (air_path != null and air == null) or str(root.get("model_id", "")).is_empty():
		return false
	from_scene = true
	model_id = str(root["model_id"])
	radius_m = _mm(footprint.radius)
	height_m = _mm(footprint.height)
	reach_m = _mm(_marker(nodes, root, "reach").z)
	capsule_height_m = ground.height
	capsule_radius_m = ground.radius
	flying_height_m = height_m
	flying_capsule_height_m = capsule_height_m
	if air != null:
		flying_height_m = _mm(air.height)
		flying_capsule_height_m = air.height
	center = _marker(nodes, root, "center")
	top = _marker(nodes, root, "top")
	feet = _marker(nodes, root, "feet")
	muzzle = _marker(nodes, root, "muzzle") if root.has("muzzle") else _hand(height_m, reach_m)
	return true


## The shape of the CollisionShape3D the root's `prop` points at, or null.
static func _shape(nodes: Dictionary, root: Dictionary, prop: String) -> Shape3D:
	if not root.has(prop):
		return null
	var props: Dictionary = nodes.get(String(root[prop]), {})
	return props.get("shape") as Shape3D


## The local position of the Marker3D the root's `prop` points at (zero when it is not saved or has no transform).
static func _marker(nodes: Dictionary, root: Dictionary, prop: String) -> Vector3:
	if not root.has(prop):
		return Vector3.ZERO
	var props: Dictionary = nodes.get(String(root[prop]), {})
	var xform: Variant = props.get("transform")
	return (xform as Transform3D).origin if xform is Transform3D else Vector3.ZERO


## The double a measure of at most 3 decimals had before the scene stored it in 32 bits.
static func _mm(value: float) -> float:
	return roundi(value * 1000.0) / 1000.0


static func _hand(height: float, reach: float) -> Vector3:
	return Vector3(0.0, height, 0.0) * _HAND_FRACTION + Vector3(0.0, 0.0, reach)
