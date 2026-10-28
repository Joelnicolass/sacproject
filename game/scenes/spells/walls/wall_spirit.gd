class_name WallSpirit
extends FxScene

## A spirit of the Wailing Wall: a glowing green comet that drags a ribbon of the last 90 ticks of its flight (the ribbon of Animate Dead's
## streams, with `wlsp`). A PATROL spirit (twelve in the wall's scene) flies from point to point along the wall, at any height of it, appears
## while the wall grows and goes out, one after another over 4 s, once it sinks. An ORBIT spirit (FxBus plays its own scene on the body
## the wall slowed) circles that body for `ticks`, closing in at the end. Presentation only, on every peer; it does not slow anybody
## (WallTouch). Its dice are its own.

enum Mode { PATROL, ORBIT }

@export var mode := Mode.PATROL
@export var wall: SpellWall
## PATROL: which of `count` spirits this is; it is born when the wall has grown `index / count` of the way and goes out in that order.
@export var index := 0
@export var count := 12
## The ribbon: atlas strip, links, width and brightness.
@export var type: BeamType
@export_range(0.0, 200.0, 1.0) var acceleration := 90.0
@export_range(0.0, 100.0, 1.0) var speed := 20.0
## PATROL: it looks for a new place when it is this close to the one it flies to, and picks one up to `hop_m` along the wall.
@export_range(0.5, 20.0, 0.5, "suffix:m") var arrive_m := 5.0
@export_range(1.0, 60.0, 1.0, "suffix:m") var hop_m := 20.0
@export_range(0.0166, 10.0, 0.0001, "suffix:s") var trail_s := 1.5
@export_range(0.5, 20.0, 0.5, "suffix:s") var fade_s := 4.0
## ORBIT: turns a second and the gap between it and the body's box, in metres.
@export_range(0.1, 4.0, 0.05) var turns_per_s := 1.0
@export_range(0.0, 3.0, 0.1, "suffix:m") var gap_m := 0.5

var _rng: RandomNumberGenerator
var _mesh := ImmediateMesh.new()
var _here := Vector3.ZERO
var _going := Vector3.ZERO
var _velocity := Vector3.ZERO
var _trail := PackedVector3Array()
var _owed := 0.0
var _ticks := 0
var _life := 0
var _target: Node3D
var _phase := 0.0

@onready var _view: MeshInstance3D = %Mesh


func _ready() -> void:
	if (
		(mode == Mode.PATROL and wall == null)
		or type == null
		or DisplayServer.get_name() == "headless"
	):
		set_process(false)
		return
	_rng = MatchSeed.rng(["wall_spirit", String(name), index])
	top_level = true
	global_transform = Transform3D.IDENTITY
	_view.mesh = _mesh
	_view.material_override = BeamFx.material_for(type)
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.custom_aabb = AABB(Vector3(-400.0, -50.0, -400.0), Vector3(800.0, 200.0, 800.0))


## FxBus.play_scene (ORBIT): `target` the body's path, `ticks` how long it circles it.
func play(params: Dictionary) -> void:
	_target = get_tree().root.get_node_or_null(NodePath(str(params.get("target", "")))) as Node3D
	_life = int(params.get("ticks", 480))
	_phase = _rng.randf() * TAU
	if _target == null:
		queue_free()


func _process(delta: float) -> void:
	if not _alive():
		_mesh.clear_surfaces()
		if mode == Mode.ORBIT and _life > 0 and _ticks >= _life:
			queue_free()
		return
	if _trail.is_empty():
		_here = _orbit() if mode == Mode.ORBIT else _pick(0.0, true)
		_going = (
			_pick(WallRules.along(_here, wall.center, wall.direction))
			if mode == Mode.PATROL
			else _here
		)
		_trail.resize(maxi(1, MatchClock.ticks_for(trail_s)))
		_trail.fill(_here)
	_owed += delta * MatchClock.TICKS_PER_SECOND_F
	while _owed >= 1.0:
		_owed -= 1.0
		_ticks += 1
		_fly(1.0 / MatchClock.TICKS_PER_SECOND_F)
	_draw()


func _alive() -> bool:
	if mode == Mode.ORBIT:
		return _target != null and is_instance_valid(_target) and _ticks < _life
	var gone_at := (
		(
			wall.vanish_at
			+ roundi(fade_s * MatchClock.TICKS_PER_SECOND_F * float(index) / float(count))
		)
		if wall.vanish_at >= 0
		else -1
	)
	return wall.age * count >= wall.grow_ticks * index and (gone_at < 0 or wall.age < gone_at)


func _fly(step: float) -> void:
	if mode == Mode.ORBIT:
		_here = _orbit()
	else:
		_velocity += acceleration * (_going - _here).normalized() * step
		if _velocity.length() > 5.0:
			_velocity = speed * _velocity.normalized()
		_here += _velocity * step
		if _here.distance_to(_going) < arrive_m:
			_going = _pick(WallRules.along(_here, wall.center, wall.direction))
	_trail.remove_at(_trail.size() - 1)
	_trail.insert(0, _here)


## The point of the circle round the body's box now; the circle closes in over the last third of the time.
func _orbit() -> Vector3:
	var box := BodyNudge.box(_target)
	var radius := (
		(0.5 * box.size.length() + gap_m)
		* minf(1.0, 3.0 * float(_life - _ticks) / float(maxi(_life, 1)))
	)
	var angle := _phase + TAU * turns_per_s * float(_ticks) / MatchClock.TICKS_PER_SECOND_F
	return (
		box.get_center()
		+ Vector3(cos(angle) * radius, 0.4 * radius * sin(2.3 * angle), sin(angle) * radius)
	)


## A point of the wall within `hop_m` of metre `from` (or anywhere along it), at any height of it and over its thickness.
func _pick(from: float, anywhere := false) -> Vector3:
	var low := wall.left * 1.2
	var high := wall.right * 1.2
	var t := (
		_rng.randf_range(low, high)
		if anywhere
		else _rng.randf_range(maxf(low, from - hop_m), minf(high, from + hop_m))
	)
	var across := (
		WallRules.across(wall.direction) * (0.45 * wall.thickness_m() * _rng.randf_range(-1.0, 1.0))
	)
	return (
		wall.point_at(t)
		+ Vector3(across.x, _rng.randf_range(0.2, 1.0) * maxf(wall.top(), 1.0), across.y)
	)


func _draw() -> void:
	_mesh.clear_surfaces()
	var n := type.segments
	var points := PackedVector3Array()
	var turns: Array[Quaternion] = []
	for i in n + 1:
		var link := mini(i * 3, _trail.size() - 2)
		points.append(_trail[link])
		var tangent := _trail[link] - _trail[link + 1]
		var along := tangent.normalized() if tangent.length_squared() > 0.000001 else Vector3.BACK
		turns.append(
			(
				Quaternion(Vector3.BACK, along)
				if along.dot(Vector3.BACK) > -0.9999
				else Quaternion(Vector3.RIGHT, PI)
			)
		)
	_view.set_instance_shader_parameter(
		&"cell",
		float(
			(
				int(floor(Time.get_ticks_msec() / 1000.0 / type.frame_s))
				% (type.h_frames * type.v_frames)
			)
		)
	)
	_view.set_instance_shader_parameter(&"energy", type.energy_max)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		for j in 3:
			StreamerFx.add_fin(_mesh, points, turns, i, j, n, type.width_m)
	_mesh.surface_end()
