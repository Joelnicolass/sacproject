class_name GrassTrample
extends RefCounted

## Keeps the stamps the grass shader flattens blades under: one live stamp per nearby unit (it
## follows the body each frame) plus a trail of stamps that fade, so the grass stands up slowly
## after a unit walks on. CPU: a handful of vector writes per frame and a group scan every
## `scan_s`; the shader does the rest. Reads bodies, never changes them.

const LIVE_MAX := 16
const TRAIL_MAX := 32
const TOTAL := LIVE_MAX + TRAIL_MAX
const GROUPS: Array[StringName] = [&"unit", &"wizard"]

var recover_s := 2.0
var radius_scale := 1.5
var scan_s := 0.2
var drop_distance_m := 0.45

var _bodies: Array[Node3D] = []
var _radius: Array[float] = []
var _last_drop: Array[Vector2] = []
var _trail: Array[Vector4] = []
var _trail_age: Array[float] = []
var _scan_left := 0.0

## Stamps for the shader: x, z (map), radius, strength 0..1. Padded to `TOTAL`.
var stamps := PackedVector4Array()
## How many leading entries of `stamps` are in use (compact: live stamps, then the trail).
var count := 0


func _init() -> void:
	stamps.resize(TOTAL)


func clear() -> void:
	_bodies.clear()
	_radius.clear()
	_last_drop.clear()
	_trail.clear()
	_trail_age.clear()
	stamps.fill(Vector4.ZERO)
	count = 0


## Call every frame. `center` and `radius_m` bound the scan to what the field draws.
func update(delta: float, tree: SceneTree, space: Node3D, center: Vector2, radius_m: float, ground_y: Callable) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = scan_s
		_scan(tree, space, center, radius_m, ground_y)
	var n := 0
	var out := PackedVector4Array()
	out.resize(TOTAL)
	var live := 0
	for i in _bodies.size():
		var body := _bodies[i]
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var local := space.to_local(body.global_position)
		var at := Vector2(local.x, local.z)
		out[n] = Vector4(at.x, at.y, _radius[i], 1.0)
		n += 1
		live += 1
		if i < _last_drop.size() and at.distance_to(_last_drop[i]) >= drop_distance_m:
			_last_drop[i] = at
			_trail.append(Vector4(at.x, at.y, _radius[i], 1.0))
			_trail_age.append(0.0)
			if _trail.size() > TRAIL_MAX:
				_trail.pop_front()
				_trail_age.pop_front()
	var keep := 0
	for i in _trail.size():
		_trail_age[i] += delta
		var strength := 1.0 - _trail_age[i] / maxf(recover_s, 0.01)
		if strength <= 0.0:
			continue
		_trail[keep] = _trail[i]
		_trail_age[keep] = _trail_age[i]
		keep += 1
		var stamp := _trail[i]
		stamp.w = strength * strength
		if n < TOTAL:
			out[n] = stamp
			n += 1
	_trail.resize(keep)
	_trail_age.resize(keep)
	stamps = out
	count = n


func _scan(tree: SceneTree, space: Node3D, center: Vector2, radius_m: float, ground_y: Callable) -> void:
	var seen := {}
	var found: Array[Node3D] = []
	for group in GROUPS:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or seen.has(body.get_instance_id()) or body.is_in_group("corpse"):
				continue
			seen[body.get_instance_id()] = true
			var local := space.to_local(body.global_position)
			if Vector2(local.x, local.z).distance_to(center) > radius_m:
				continue
			# Flyers do not touch the grass.
			var floor_y: float = ground_y.call(local.x, local.z)
			if local.y - floor_y > 2.2:
				continue
			found.append(body)
	found.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return space.to_local(a.global_position).distance_squared_to(Vector3(center.x, 0.0, center.y)) < space.to_local(b.global_position).distance_squared_to(Vector3(center.x, 0.0, center.y)))
	if found.size() > LIVE_MAX:
		found.resize(LIVE_MAX)
	# Keep the drop memory of the bodies that stay.
	var drops := {}
	for i in _bodies.size():
		if is_instance_valid(_bodies[i]):
			drops[_bodies[i].get_instance_id()] = _last_drop[i]
	_bodies = found
	_radius.clear()
	_last_drop.clear()
	for body in found:
		_radius.append(maxf(BodySeparation.half_size(body), 0.25) * radius_scale)
		var local := space.to_local(body.global_position)
		_last_drop.append(drops.get(body.get_instance_id(), Vector2(local.x, local.z)))
