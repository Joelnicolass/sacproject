class_name StreamerFx
extends MeshInstance3D

## One stream of Animate Dead: a ghostly comet that leaves the wizard, arcs up and falls on the creature coming back to life. A ribbon of
## `type.segments` links with three fins, its texture stretched along its whole length (a strip of frames, one every `type.frame_s`).
## Only a part of the curve shows at once (`length` of it), and that part travels from the wizard to the creature in `travel_s`. The two
## ends follow their bodies. Presentation only: no sound, no damage, no state; AnimateDeadFx makes it and it frees itself.
## Ref: sacengine animateDeadEffect and renderAnimateDead (state.d:18328-18334, renderer.d:2341-2358).

const UV_INSET := 0.5 / 256.0

## The look: atlas strip (`h_frames` x `v_frames`), segments, width of the fins, frame time and brightness.
@export var type: BeamType
## Seconds the head takes to go from the wizard to the creature (and the tail to arrive after it).
@export_range(0.1, 10.0, 0.01, "suffix:s") var travel_s := 128.0 / 60.0
## The part of the curve that shows at once, between these two fractions (each stream picks its own).
@export var length_range := Vector2(0.15, 0.5)
## How steeply the stream leaves the wizard and falls on the creature (up and down, against the random side push).
@export_range(0.0, 8.0, 0.1) var arc := 3.0
@export_range(0.0, 8.0, 0.1) var side_push := 2.0

var _from: Node3D
var _to: Node3D
var _out := Vector3.ZERO
var _in := Vector3.ZERO
var _length := 0.3
var _t := 0.0
var _mesh := ImmediateMesh.new()
var _last_from := Vector3.ZERO
var _last_to := Vector3.ZERO


func _ready() -> void:
	mesh = _mesh
	global_transform = Transform3D.IDENTITY
	if type != null:
		material_override = BeamFx.material_for(type)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Starts the stream from `from` to `to` (bodies: their centers are the ends). `stream_seed` picks its arc.
func play(from: Node3D, to: Node3D, stream_seed: int) -> void:
	_from = from
	_to = to
	var rng := RandomNumberGenerator.new()
	rng.seed = stream_seed
	_last_from = BodyNudge.center(from)
	_last_to = BodyNudge.center(to)
	var distance := _last_from.distance_to(_last_to)
	_out = 2.0 * (Vector3.UP * arc + side_push * _direction(rng)).normalized() * distance
	_in = 2.0 * (Vector3.DOWN * arc + side_push * _direction(rng)).normalized() * distance
	_length = rng.randf_range(length_range.x, length_range.y)
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= travel_s:
		queue_free()
		return
	if is_instance_valid(_from):
		_last_from = BodyNudge.center(_from)
	if is_instance_valid(_to):
		_last_to = BodyNudge.center(_to)
	_draw()


func _draw() -> void:
	_mesh.clear_surfaces()
	var n := type.segments
	var head := (1.0 + _length) * _t / travel_s
	var tail := head - _length
	var points := PackedVector3Array()
	var turns: Array[Quaternion] = []
	for i in n + 1:
		var progress := clampf(lerpf(head, tail, float(i) / n), 0.0, 1.0)
		var at := CarrierPath.hermite(_last_from, _out, _last_to, _in, progress)
		var ahead := CarrierPath.hermite(_last_from, _out, _last_to, _in, minf(progress + 0.01, 1.0))
		var tangent := (ahead - at) if ahead != at else (_last_to - _last_from)
		points.append(at)
		turns.append(Quaternion(Vector3.BACK, tangent.normalized()) if tangent.normalized().dot(Vector3.BACK) > -0.9999 else Quaternion(Vector3.RIGHT, PI))
	var cells := type.h_frames * type.v_frames
	set_instance_shader_parameter(&"cell", float(int(floor(_t / type.frame_s)) % cells))
	set_instance_shader_parameter(&"energy", type.energy_max)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		for j in 3:
			_add_fin(points, turns, i, j, n)
	_mesh.surface_end()


## The quad of fin `j` between link `i` and `i + 1`: the axis along the bottom of the cell, the fin's edge along the top.
func _add_fin(points: PackedVector3Array, turns: Array[Quaternion], i: int, j: int, n: int) -> void:
	var sqrt34 := sqrt(0.75)
	var fins: Array[Vector3] = [Vector3(0.0, -1.0, 0.0), Vector3(sqrt34, 0.5, 0.0), Vector3(-sqrt34, 0.5, 0.0)]
	var corners: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for k in 4:
		var link := i + 1 if (k == 1 or k == 2) else i
		var edge := k == 2 or k == 3
		corners.append(points[link] + (turns[link] * (fins[j] * type.width_m) if edge else Vector3.ZERO))
		uvs.append(Vector2(clampf(float(link) / n, UV_INSET, 1.0 - UV_INSET), UV_INSET if edge else 1.0 - UV_INSET))
	for index in [0, 1, 2, 2, 3, 0]:
		_mesh.surface_set_uv(uvs[index])
		_mesh.surface_add_vertex(corners[index])


static func _direction(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
