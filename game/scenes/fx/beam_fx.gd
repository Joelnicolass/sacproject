class_name BeamFx
extends MeshInstance3D

## A lightning bolt between two points: `type.bolts` ribbons of 3 fins at 120°, each following its
## own LightningBolt, that change shape every `change_s`, travel in from the start, pulse in
## brightness and leave from the start before dying. The end can follow a node (the target's center
## moves while it burns).
## Presentation only: FxBus plays it, it moves nothing, and the shape comes from a generator of its
## own. Frees itself at the end of its life, unless FxBus pools it (then it hides and says
## `finished`).

signal finished
## The bolt reached its end (once per play), at that point: a ScarMark of the scene can burn the
## ground there.
signal struck(at: Vector3)

const SHADER := preload("res://scenes/fx/beam.gdshader")
const SHADER_MIX := preload("res://scenes/fx/beam_mix.gdshader")
const UV_INSET := 0.5 / 64.0

static var _materials: Dictionary = {}

@export var type: BeamType
## Owned by FxBus's pool: it waits hidden for `play` and hides again at the end instead of freeing
## itself.
@export var pooled := false

var _imesh: ImmediateMesh
var _rng := RandomNumberGenerator.new()
var _bolts: Array[LightningBolt] = []
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _follow: Node3D
var _follow_offset := Vector3.ZERO
var _t := 0.0
var _shape := 0
var _flashed := false
var _live := false
var _tip_left := 0.0


func _ready() -> void:
	global_transform = Transform3D.IDENTITY
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	if type != null:
		material_override = material_for(type)
	visible = false
	set_process(false)


## Starts the beam from `from` to `to`. With `follow`, the end keeps its offset from that node while
## the node lives. `beam_seed` picks the shapes (same seed, same bolt).
func play(from: Vector3, to: Vector3, beam_seed: int, follow: Node3D = null) -> void:
	if type == null:
		return
	if material_override == null:
		material_override = material_for(type)
	_from = from
	_to = to
	_follow = follow
	_follow_offset = to - follow.global_position if follow != null else Vector3.ZERO
	_rng.seed = beam_seed
	_bolts.clear()
	for i in type.bolts:
		var bolt := LightningBolt.new(type.segments)
		bolt.change_shape(_rng, type.jitter_m)
		_bolts.append(bolt)
	_t = 0.0
	_shape = 0
	_flashed = false
	_live = true
	visible = true
	set_process(true)
	_draw()


## End of the bolt now (the followed node's point while it lives).
func _end_point() -> Vector3:
	if _follow != null and is_instance_valid(_follow) and _follow.is_inside_tree():
		_to = _follow.global_position + _follow_offset
	return _to


func _process(delta: float) -> void:
	_t += delta
	if _t >= type.life_s:
		_stop()
		return
	var wanted := int(floor(_t / type.change_s))
	while _shape < wanted:
		_shape += 1
		for bolt in _bolts:
			bolt.change_shape(_rng, type.jitter_m)
	if not _flashed and _t >= type.travel_s:
		_flashed = true
		_flash()
	_sparkle_tip(delta)
	_draw()


## Ends the bolt now, as if its life were over (the warm-up's flash). Nothing when it is not
## playing.
func stop() -> void:
	if _live:
		_stop()


func _stop() -> void:
	_live = false
	_follow = null
	_imesh.clear_surfaces()
	visible = false
	set_process(false)
	finished.emit()
	if not pooled:
		queue_free()


func _flash() -> void:
	struck.emit(_end_point())
	if type.light != null and is_inside_tree():
		type.light.light_up(get_tree(), self, _end_point())


## While the tip travels, sprites stay behind it (Rainbow's glow): a few every tick, in a ball
## around the tip.
func _sparkle_tip(delta: float) -> void:
	if type.tip_type == null or _t >= type.travel_s:
		return
	_tip_left -= delta
	var tip := (
		_arc_point(_from, _end_point(), type.span_at(_t).y)
		if type.path == BeamType.Path.ARC
		else _from.lerp(_end_point(), type.span_at(_t).y)
	)
	while _tip_left <= 0.0:
		_tip_left += 1.0 / type.tip_per_s
		var around := Vector3(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
		)
		FxBus.puff(type.tip_type, tip + around.limit_length(1.0) * type.tip_spread_m)


## The point at `t` (0 = start, 1 = end) of a vertical half circle from `a` to `b`: the ground track
## runs along the chord with the speed of a half circle, the height is the arc over the straight mix
## of the ends' heights.
func _arc_point(a: Vector3, b: Vector3, t: float) -> Vector3:
	var angle := PI * clampf(t, 0.0, 1.0)
	var along := 0.5 * (1.0 - cos(angle))
	var flat := Vector2(b.x - a.x, b.z - a.z).length()
	return a.lerp(b, along) + Vector3(0.0, flat * type.arc_height * sin(angle), 0.0)


func _draw() -> void:
	_imesh.clear_surfaces()
	var start := _from
	var diff := _end_point() - start
	var length := diff.length()
	if length < 0.001 or _bolts.is_empty():
		return
	var axis := diff / length
	var turn := (
		Quaternion(Vector3.BACK, axis)
		if axis.dot(Vector3.BACK) > -0.9999
		else Quaternion(Vector3.RIGHT, PI)
	)
	var sqrt34 := sqrt(0.75)
	var fins: Array[Vector3] = [
		turn * (Vector3(0.0, -1.0, 0.0) * type.width_m),
		turn * (Vector3(sqrt34, 0.5, 0.0) * type.width_m),
		turn * (Vector3(-sqrt34, 0.5, 0.0) * type.width_m),
	]
	var span := type.span_at(_t)
	var n := type.segments
	var points := PackedVector3Array()
	points.resize(n + 1)
	InstanceParams.set_on(
		self, &"cell", float(int(floor(_t / type.frame_s)) % (type.h_frames * type.v_frames))
	)
	InstanceParams.set_on(self, &"energy", type.energy_at(_t))
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for bolt in _bolts:
		for k in n + 1:
			var at := clampf(float(k) / float(n), span.x, span.y)
			if type.path == BeamType.Path.ARC:
				points[k] = _arc_point(start, start + diff, at)
				continue
			var p := bolt.sample(at)
			points[k] = start + turn * Vector3(p.x, p.y, p.z * length)
		_add_ribbon(points, fins, n)
	_imesh.surface_end()


## Builds the ribbon: per segment and fin a quad from the axis to the fin's edge, pointed at both
## ends; u flips every segment, v = 1 on the axis (the bright row of the cell).
func _add_ribbon(points: PackedVector3Array, fins: Array[Vector3], n: int) -> void:
	for i in n:
		for j in 3:
			var pos: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in 4:
				var bone := i + 1 if (k == 1 or k == 2) else i
				var p := points[bone]
				if (k == 2 or k == 3) and bone != 0 and bone != n:
					p += fins[j]
				pos.append(p)
				var flip := ((i & 1) == 1) != (k == 1 or k == 2)
				uvs.append(
					Vector2(
						1.0 - UV_INSET if flip else UV_INSET,
						1.0 - UV_INSET if (k == 0 or k == 1) else UV_INSET
					)
				)
			for idx in [0, 1, 2, 2, 3, 0]:
				_imesh.surface_set_uv(uvs[idx])
				_imesh.surface_add_vertex(pos[idx])


## Shared material of a BeamType (its cell and brightness are instance uniforms). Parameters are
## refreshed on every call, so an edit in the inspector shows up on the next pooled beam built.
static func material_for(beam: BeamType) -> ShaderMaterial:
	var material: ShaderMaterial = _materials.get(beam)
	if material == null:
		material = ShaderMaterial.new()
		_materials[beam] = material
	material.shader = SHADER_MIX if beam.blend == BeamType.Blend.MIX else SHADER
	material.set_shader_parameter("use_textures", beam.atlas != null)
	material.set_shader_parameter("atlas", beam.atlas)
	material.set_shader_parameter("h_frames", beam.h_frames)
	material.set_shader_parameter("v_frames", beam.v_frames)
	material.set_shader_parameter("soft_distance_m", beam.soft_distance_m)
	return material
