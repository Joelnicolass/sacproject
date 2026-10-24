class_name VineLook
extends Node3D

## The vines that hold a body: sixteen skinned tubes (the scene's `vine.glb` instances) rooted at its feet, tip in the upper half of its box.
## Each follows a spline through four control points; the two middle ones are damped springs that are pushed again when they rest, so the
## vines never stop twisting. They grow when the state goes on and shrink when it ends. It does not decide when the state is on
## (Affliction) nor hold the body (Vined). Presentation only, on every peer, from the replicated mask; its shapes use a stream of their own.
## Ref: sacengine GraspingVines (state.d:17825-17876, renderer.d:2232-2259).

## The state that shows it, and the body whose box it fills.
@export var affliction: Affliction
@export var body: Node3D
## Lit and opaque, with the vine texture (the tube's UV: u around, v along).
@export var material: Material
@export_range(1, 300) var grow_ticks := 60
@export_group("Springs")
## Acceleration of a control point toward its place is this over the vine's scale; the speed halves every `half_life_s` and stops at `max_speed`.
@export var spring := 90.0
@export var half_life_s := 1.0
@export var max_speed := 20.0
## A control point slower than this gets a push in a random direction of this strength (m/s).
@export var rest_speed := 0.3
@export var push := 3.0

var _skeletons: Array[Skeleton3D] = []
var _vines: Array[Dictionary] = []
var _length := 0.0
var _growing := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	visible = false
	set_process(false)
	if Engine.is_editor_hint() or affliction == null:
		return
	for node in find_children("*", "Skeleton3D", true, false):
		_skeletons.append(node as Skeleton3D)
		for mesh in node.find_children("*", "MeshInstance3D", false, false):
			(mesh as MeshInstance3D).material_override = material
	affliction.shown_changed.connect(_on_shown)
	if affliction.is_on():
		_on_shown(true)


func _on_shown(on: bool) -> void:
	_growing = on
	if on:
		_length = maxf(_length, 0.1)
		if _vines.is_empty() or _length <= 0.1:
			_throw()
		visible = true
	set_process(true)


func _process(delta: float) -> void:
	var step := delta * MatchClock.TICKS_PER_SECOND_F / float(grow_ticks)
	_length = clampf(_length + (step if _growing else -step), 0.0, 1.0)
	if not _growing and _length <= 0.0:
		visible = false
		set_process(false)
		return
	for i in _vines.size():
		_move(i, minf(delta, 0.05))


## New roots, tips and spring points for every vine (one throw per time the state goes on).
func _throw() -> void:
	MatchSeed.seed_rng(_rng, ["vines_look", String(body.name)])
	var box := BodyNudge.box(body)
	var half := box.size * 0.5
	var scale_m := maxf(0.2, box.size.length() * 0.5)
	var feet := body.to_local(Vector3(box.get_center().x, box.position.y, box.get_center().z))
	_vines.clear()
	for skeleton in _skeletons:
		var tip := feet + Vector3(_rng.randf_range(-half.x, half.x), _rng.randf_range(half.y, box.size.y), _rng.randf_range(-half.z, half.z))
		var root := Vector3(tip.x + _rng.randf_range(-1.0, 1.0) * 0.7, feet.y - 0.1 * scale_m, tip.z + _rng.randf_range(-1.0, 1.0) * 0.7)
		skeleton.position = root
		skeleton.scale = Vector3.ONE * scale_m
		_vines.append({"root": root, "tip": tip, "scale": scale_m, "p": [root.lerp(tip, 0.33), root.lerp(tip, 0.66)], "v": [Vector3.ZERO, Vector3.ZERO]})


## One step of the springs of a vine, then its bones along the spline.
func _move(index: int, delta: float) -> void:
	var vine := _vines[index]
	var root: Vector3 = vine["root"]
	var tip: Vector3 = vine["tip"]
	var scale_m: float = vine["scale"]
	var points: Array = vine["p"]
	var speeds: Array = vine["v"]
	for k in 2:
		var home := root.lerp(tip, 0.33 + 0.33 * k)
		var speed: Vector3 = speeds[k] + (home - points[k] as Vector3) * (spring / scale_m) * delta
		speed *= pow(0.5, delta / half_life_s)
		if speed.length() < rest_speed:
			speed += Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * push
		speeds[k] = speed.limit_length(max_speed)
		points[k] = points[k] + speeds[k] * delta
	_pose(_skeletons[index], root, root, points[0], points[1], root.lerp(tip, _length), scale_m)


## The bones on the cubic spline root -> two springs -> tip (the tip at `_length` of the way); each bone looks along the curve.
func _pose(skeleton: Skeleton3D, root: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, tip: Vector3, scale_m: float) -> void:
	var count := skeleton.get_bone_count()
	var side := Vector3.RIGHT
	for bone in count:
		var t := float(bone) / float(count - 1)
		var u := 1.0 - t
		var at := p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + tip * (t * t * t)
		var along := (p1 - p0) * (3.0 * u * u) + (p2 - p1) * (6.0 * u * t) + (tip - p2) * (3.0 * t * t)
		if along.length_squared() < 0.000001:
			along = Vector3.UP
		var up := along.normalized()
		side = (side - up * side.dot(up))
		side = side.normalized() if side.length_squared() > 0.000001 else up.cross(Vector3.FORWARD).normalized()
		var basis := Basis(side, up, side.cross(up))
		skeleton.set_bone_global_pose(bone, Transform3D(basis, (at - root) / scale_m))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if affliction == null or body == null:
		warnings.append("Faltan affliction y body.")
	return warnings
