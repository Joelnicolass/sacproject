class_name BodyFacts
extends RefCounted

## The size and sockets of a body that the rules need (how tall, how wide, how far its blow reaches, where its hand and center are),
## read once from its BodyFrame scene and kept. A creature or wizard asks its BodyMount for them; nothing loads a scene or searches
## a node per frame. Values are the ones saved in the scene (32-bit, as the shapes and markers hold them); nothing here is decoded.
## What it does not do: move a body, size a physics shape (BodyCollider) or choose which scene a body wears (BodyMount).

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


func _init() -> void:
	muzzle = _hand(height_m, reach_m)


## The facts of the body scene `scene` (built once and shared). The unknown-model default for null.
## A dictionary lookup after the first call, never a load: safe per tick.
static func of(scene: PackedScene) -> BodyFacts:
	if scene == null:
		return fallback()
	if not _cache.has(scene):
		var built := fallback()
		var root := scene.instantiate()
		var frame := root as BodyFrame
		if frame != null and frame.is_complete():
			built = BodyFacts.new()._read(frame)
		if root != null:
			root.free()
		_cache[scene] = built
	return _cache[scene]


## The facts of the body scene `body` wears (a UnitBody, WizardBody or DoctorBody has a `mount`); the default for anything else.
static func of_body(body: Object) -> BodyFacts:
	var found: Variant = body.get("mount") if body != null and "mount" in body else null
	var mount := found as BodyMount
	return mount.facts if mount != null else fallback()


## The size of a body with no scene: 1.8 m tall, 0.35 m wide, 0.35 m of reach.
static func fallback() -> BodyFacts:
	if _fallback == null:
		_fallback = BodyFacts.new()
	return _fallback


## Half the width of the box: the larger of the footprint radius and the reach.
func half_size_m() -> float:
	return maxf(radius_m, reach_m)


func _read(frame: BodyFrame) -> BodyFacts:
	from_scene = true
	model_id = frame.model_id
	var footprint := frame.footprint.shape as CylinderShape3D
	radius_m = footprint.radius
	height_m = footprint.height
	reach_m = frame.reach.position.z
	var ground := frame.capsule.shape as CapsuleShape3D
	capsule_height_m = ground.height
	capsule_radius_m = ground.radius
	flying_height_m = height_m
	flying_capsule_height_m = capsule_height_m
	if frame.flying_capsule != null:
		var air := frame.flying_capsule.shape as CapsuleShape3D
		flying_height_m = air.height
		flying_capsule_height_m = air.height
	center = frame.center.position
	top = frame.top.position
	feet = frame.feet.position if frame.feet != null else Vector3.ZERO
	muzzle = frame.muzzle.position if frame.muzzle != null else _hand(height_m, reach_m)
	return self


static func _hand(height: float, reach: float) -> Vector3:
	return Vector3(0.0, height, 0.0) * _HAND_FRACTION + Vector3(0.0, 0.0, reach)
