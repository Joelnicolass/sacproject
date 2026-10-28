class_name PullThread
extends FxScene

## The thread of a pull, a cord or a bolt from the user's shot position to the center of the target,
## growing out of the user over the first 20 frames (start + α · (end − start), α = frame / 20) and
## following both bodies after that. The web is a straight cord (`jitter` 0); the cage is a
## lightning bolt that changes its shape every 6 frames with LightningBolt, spread by `jitter`
## meters and grown from nothing to full over `ramp_s`. One event (FxBus.broadcast_scene, one RPC):
## params `user` and `target` (node paths, the bodies have the same path on every peer), `seed` (the
## shapes) and `grow_ticks` (the network sends ticks; `grow_s` without it). It ends with the bit of
## the user's Pulling (replicated), or when a body is gone; `wait_s` covers the clients whose bit
## arrives after the event. Presentation only, never headless, drawn in MIX (alpha blend, never
## additive).
## WORKAROUND: the `cord` and `ltng` textures are not in the exporter's atlases
## (tools/import/fx_catalog.py): a flat color stands in until `texture` has an atlas.
## Limits: the web / cage mesh around the target is not drawn; the cage's shape does not reset at
## each pull (the clients do not see the pull ticks): one ramp from the start.

## Time the thread takes to reach the target (20 ticks).
@export_range(0.0, 5.0, 0.0001, "suffix:s") var grow_s := 0.3333
## Half width of each fin (m).
@export var width := 0.06
## Flat fins crossing along the thread: 2 = a cross, 3 = the bolts' 120 degree fins.
@export_range(1, 4) var fins := 2
## 0 = a straight cord. > 0: a bolt of `segments` pieces whose inner points leave the axis up to
## this many meters.
@export var jitter := 0.0
@export_range(2, 32) var segments := 10
## The bolt takes a new shape every this long (6 ticks).
@export_range(0.0166, 2.0, 0.0001, "suffix:s") var reshape_s := 0.1
## The bolt grows from nothing to its full spread over this long (2 per second).
@export_range(0.0, 5.0, 0.0001, "suffix:s") var ramp_s := 0.5
## The thread's texture. Empty: the material's color.
@export var texture: Texture2D
## It frees itself when the user's Pulling was not seen on within this long (a bit that never
## arrives).
@export_range(0.0, 10.0, 0.0001, "suffix:s") var wait_s := 0.5
## ... and in any case after this long.
@export_range(0.0, 600.0, 0.0001, "suffix:s") var max_life_s := 40.0

@onready var _strand: MeshInstance3D = %Strand

var _user: Node3D
var _target: Node3D
var _born := 0
var _seen := false
var _mesh: ImmediateMesh
var _bolt: LightningBolt
var _rng: RandomNumberGenerator
var _shape_slot := -1
var _grow_ticks := 0


## FxBus.broadcast_scene: starts the thread. Nothing happens without both bodies.
func play(params: Dictionary) -> void:
	var root := get_tree().root
	_user = root.get_node_or_null(NodePath(str(params.get("user", "")))) as Node3D
	_target = root.get_node_or_null(NodePath(str(params.get("target", "")))) as Node3D
	_grow_ticks = int(params.get("grow_ticks", MatchClock.ticks_for(grow_s)))
	if _user == null or _target == null:
		queue_free()
		return
	_born = MatchClock.now()
	_rng = MatchSeed.rng(["pull_thread", int(params.get("seed", 0))])
	if jitter > 0.0:
		_bolt = LightningBolt.new(segments)
	_mesh = ImmediateMesh.new()
	_strand.mesh = _mesh
	_strand.global_transform = Transform3D.IDENTITY
	var material := _strand.material_override as StandardMaterial3D
	if texture != null and material != null:
		material.albedo_texture = texture
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	var now := MatchClock.now()
	var pulling := Pulling.of(_user) if is_instance_valid(_user) else null
	if pulling != null and pulling.is_on():
		_seen = true
	elif _seen or now - _born > MatchClock.ticks_for(wait_s):
		queue_free()
		return
	if (
		now - _born > MatchClock.ticks_for(max_life_s)
		or not is_instance_valid(_user)
		or not is_instance_valid(_target)
	):
		queue_free()
		return
	var start := _origin()
	var reach := clampf(float(now - _born) / maxf(1.0, float(_grow_ticks)), 0.0, 1.0)
	var end := start.lerp(DrawnPose.center(_target), reach)
	var ramp := clampf(
		float(now - _born) / maxf(1.0, float(MatchClock.ticks_for(ramp_s))), 0.0, 1.0
	)
	var reshape := maxi(1, MatchClock.ticks_for(reshape_s))
	if _bolt != null and now / reshape != _shape_slot:
		_shape_slot = now / reshape
		_bolt.change_shape(_rng, jitter, ramp)
	_rebuild(start, end, ramp)


## The user's shot position, else the muzzle socket of its body.
func _origin() -> Vector3:
	var unit := _user as UnitBody
	var ranged := unit.weapons.ranged if unit != null else null
	if ranged != null:
		return DrawnPose.point(_user, ranged.shot_origin())
	return DrawnPose.point(_user, BodyFacts.point(_user, BodyFacts.Socket.MUZZLE))


func _rebuild(start: Vector3, end: Vector3, ramp: float) -> void:
	_mesh.clear_surfaces()
	var line := end - start
	var length := line.length()
	if length < 0.001:
		return
	var axis := line / length
	var side := axis.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var lift := side.cross(axis).normalized()
	var count := _bolt.points.size() if _bolt != null else 2
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for fin in fins:
		var angle := PI * float(fin) / float(fins)
		var half := (side * cos(angle) + lift * sin(angle)) * width
		for i in count - 1:
			var a := _point(i, count, start, line, side, lift, ramp)
			var b := _point(i + 1, count, start, line, side, lift, ramp)
			var v0 := float(i) / float(count - 1)
			var v1 := float(i + 1) / float(count - 1)
			_quad(a - half, a + half, b + half, b - half, v0, v1)
	_mesh.surface_end()


## Point `i` of the strand: on the axis, or the bolt's point pushed off it by `ramp` of its spread.
func _point(
	i: int, count: int, start: Vector3, line: Vector3, side: Vector3, lift: Vector3, ramp: float
) -> Vector3:
	if _bolt == null:
		return start + line * (float(i) / float(count - 1))
	var local := _bolt.points[i]
	return start + line * local.z + (side * local.x + lift * local.y) * ramp


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, v0: float, v1: float) -> void:
	var uvs := [Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)]
	var points := [a, b, c, d]
	for index in [0, 1, 2, 2, 3, 0]:
		_mesh.surface_set_uv(uvs[index])
		_mesh.surface_add_vertex(points[index])
