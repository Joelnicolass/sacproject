class_name BodyFacts
extends RefCounted

## The size and sockets of a body that the rules need (how tall, how wide, how far its blow reaches,
## where its hand and center are), read once from its BodyFrame scene and kept. A creature or wizard
## asks its BodyMount for them; nothing loads a scene or searches a node per frame. The measures
## (height, radius, reach, flying height) are decoded to the mm (SceneStateReader.mm): the scene
## keeps 32 bits and the rules read them as doubles, which today come from text with at most 3
## decimals. Capsules and sockets stay 32-bit (a shape, a Vector3).
## What it does not do: move a body, size a physics shape (BodyCollider) or choose which scene a
## body wears (BodyMount).

## Fraction of the height where a thrown ball leaves the hand when the scene has no `muzzle` marker.
const _HAND_FRACTION := 0.65

## One BodyFacts per body scene, built the first time somebody asks.
static var _cache: Dictionary[PackedScene, BodyFacts] = {}
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
## The passives the creature always has (the scene instanced at the frame's `passives`), or null for
## none. PassiveMount builds it on every peer.
var passives: PackedScene


func _init() -> void:
	muzzle = _hand(height_m, reach_m)


## The facts of the body scene `scene` (built once and shared). The unknown-model default for null
## or an incomplete frame. A dictionary lookup after the first call, never a load: safe per tick.
## Read from the scene's SceneState, never instantiated: a BodyFrame instance creates physics
## objects (its Bounds Area3D) even outside the tree, and that alone moves the simulation.
static func of(scene: PackedScene) -> BodyFacts:
	if scene == null:
		return fallback()
	if not _cache.has(scene):
		var built := BodyFacts.new()
		_cache[scene] = built if built._read(scene.get_state()) else fallback()
	return _cache[scene]


## The facts of the body scene `body` wears (a UnitBody, WizardBody or DoctorBody has a `mount`).
## Anything else (a building, a structure a blow aims at, a body that wears nothing yet) reads the
## unknown-model default: 1.8 m tall, 0.35 m wide and of reach.
static func of_body(body: Object) -> BodyFacts:
	var found: Variant = body.get("mount") if body != null and "mount" in body else null
	var mount := found as BodyMount
	if mount != null:
		return mount.facts
	return fallback()


## The size of a body with no scene: 1.8 m tall, 0.35 m wide, 0.35 m of reach.
static func fallback() -> BodyFacts:
	if _fallback == null:
		_fallback = BodyFacts.new()
	return _fallback


## Where an effect leaves a body: its feet, its middle, the top of its head or the muzzle (where its
## hand or mouth throws from).
enum Socket { FEET, CENTER, TOP, MUZZLE }


## The local position of `socket` (the origin of the body is at its feet).
func local(socket: Socket) -> Vector3:
	match socket:
		Socket.FEET:
			return feet
		Socket.TOP:
			return top
		Socket.MUZZLE:
			return muzzle
	return center


## Where `socket` of `body` is in the world. A body that wears nothing gives the unknown-model
## default (1.8 m tall). Effects leave from here, never from a height typed in code.
static func point(body: Node3D, socket: Socket) -> Vector3:
	return body.global_transform * of_body(body).local(socket)


## Half the width of the box: the larger of the footprint radius and the reach.
func half_size_m() -> float:
	return maxf(radius_m, reach_m)


## Fills these facts from the saved BodyFrame `state` (its node paths, shapes and marker positions).
## False when a node the rules need is missing (the same as BodyFrame.is_complete()).
func _read(state: SceneState) -> bool:
	var nodes := SceneStateReader.nodes_of(state)
	var root: Dictionary = nodes.get(".", {})
	var footprint := SceneStateReader.shape(nodes, root, "footprint") as CylinderShape3D
	var ground := SceneStateReader.shape(nodes, root, "capsule") as CapsuleShape3D
	var air_path: Variant = root.get("flying_capsule")
	var air := SceneStateReader.shape(nodes, root, "flying_capsule") as CapsuleShape3D
	var marks: Array[String] = ["reach", "center", "top"]
	for mark: String in marks:
		if not root.has(mark) or not nodes.has(String(root[mark])):
			return false
	if (
		footprint == null
		or ground == null
		or (air_path != null and air == null)
		or str(root.get("model_id", "")).is_empty()
	):
		return false
	from_scene = true
	model_id = str(root["model_id"])
	radius_m = SceneStateReader.mm(footprint.radius)
	height_m = SceneStateReader.mm(footprint.height)
	reach_m = SceneStateReader.mm(SceneStateReader.marker(nodes, root, "reach").z)
	capsule_height_m = ground.height
	capsule_radius_m = ground.radius
	flying_height_m = height_m
	flying_capsule_height_m = capsule_height_m
	if air != null:
		flying_height_m = SceneStateReader.mm(air.height)
		flying_capsule_height_m = air.height
	center = SceneStateReader.marker(nodes, root, "center")
	top = SceneStateReader.marker(nodes, root, "top")
	feet = SceneStateReader.marker(nodes, root, "feet")
	muzzle = (
		SceneStateReader.marker(nodes, root, "muzzle")
		if root.has("muzzle")
		else _hand(height_m, reach_m)
	)
	passives = SceneStateReader.instance(state, root, "passives")
	return true


static func _hand(height: float, reach: float) -> Vector3:
	return Vector3(0.0, height, 0.0) * _HAND_FRACTION + Vector3(0.0, 0.0, reach)
