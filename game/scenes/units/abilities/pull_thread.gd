class_name PullThread
extends Node3D

## F128 (RFC-030 030q-a), F154 (030q-b): the thread of a pull, as renderer.d draws it (webPulls 3551-3565, cagePulls 1931-1946):
## from the user's shot position to the center of the target, growing out of the user over the first 20 frames
## (renderCord(start, (1 − α) · start + α · end), α = frame / numShootFrames) and following both bodies after that. The web
## is a straight cord (`jitter` 0); the cage is a lightning bolt that changes its shape every 6 frames (changeShape, 5126-5136)
## with LightningBolt, spread by `jitter` meters and grown from nothing to full over `ramp_ticks`.
## One event (FxBus.broadcast_scene, one RPC): params `user` and `target` (node paths, the bodies have the same path on every
## peer), `seed` (the shapes) and `grow_ticks`. It ends with the bit of the user's Pulling (replicated), or when a body is
## gone; `wait_ticks` covers the clients whose bit arrives after the event. Presentation only, never headless, drawn in MIX
## (alpha blend, never additive).
## WORKAROUND: the textures of the original (TXTR `cord`, `ltng`) are not in the exporter's atlases (tools/import/fx_catalog.py):
## a flat color stands in until `texture_tag` has an atlas.
## Divergences (declared): the web / cage mesh around the target is not drawn; the cage's shape does not reset at each pull
## (the clients do not see the pull ticks): one ramp from the start.

## Ticks the thread takes to reach the target (sacengine Pull.numShootFrames).
@export var grow_ticks := 20
## Half width of each fin (m).
@export var width := 0.06
## Flat fins crossing along the thread: 2 = a cross, 3 = the bolts' 120 degree fins.
@export_range(1, 4) var fins := 2
## 0 = a straight cord. > 0: a bolt of `segments` pieces whose inner points leave the axis up to this many meters.
@export var jitter := 0.0
@export_range(2, 32) var segments := 10
## The bolt takes a new shape every this many ticks (sacengine changeShapeDelay 6).
@export var reshape_ticks := 6
## The bolt grows from nothing to its full spread over this many ticks (sacengine boltScaleGrowth 2 per second).
@export var ramp_ticks := 30
## Texture tag of the atlas (FxAtlas). Empty or missing: the material's color.
@export var texture_tag := ""
## It frees itself when the user's Pulling was not seen on within this many ticks (a bit that never arrives).
@export var wait_ticks := 30
## ... and in any case after this many ticks.
@export var max_life_ticks := 2400

@onready var _strand: MeshInstance3D = %Strand

var _user: Node3D
var _target: Node3D
var _born := 0
var _seen := false
var _mesh: ImmediateMesh
var _bolt: LightningBolt
var _rng: RandomNumberGenerator
var _shape_slot := -1


## FxBus.broadcast_scene: starts the thread. Nothing happens without both bodies.
func play(params: Dictionary) -> void:
	var root := get_tree().root
	_user = root.get_node_or_null(NodePath(str(params.get("user", "")))) as Node3D
	_target = root.get_node_or_null(NodePath(str(params.get("target", "")))) as Node3D
	grow_ticks = int(params.get("grow_ticks", grow_ticks))
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
	var texture := FxAtlas.texture(texture_tag)
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
	elif _seen or now - _born > wait_ticks:
		queue_free()
		return
	if now - _born > max_life_ticks or not is_instance_valid(_user) or not is_instance_valid(_target):
		queue_free()
		return
	var start := _origin()
	var reach := clampf(float(now - _born) / maxf(1.0, float(grow_ticks)), 0.0, 1.0)
	var end := start.lerp(BodyNudge.center(_target), reach)
	var ramp := clampf(float(now - _born) / maxf(1.0, float(ramp_ticks)), 0.0, 1.0)
	if _bolt != null and now / maxi(1, reshape_ticks) != _shape_slot:
		_shape_slot = now / maxi(1, reshape_ticks)
		_bolt.change_shape(_rng, jitter, ramp)
	_rebuild(start, end, ramp)


## The user's shot position (sacengine shotPosition), else a hand above its feet.
func _origin() -> Vector3:
	var ranged := _user.get_node_or_null("RangedAttack") as RangedAttack
	if ranged != null:
		return ranged.shot_origin()
	return _user.global_position + Vector3.UP * 1.5


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
func _point(i: int, count: int, start: Vector3, line: Vector3, side: Vector3, lift: Vector3, ramp: float) -> Vector3:
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
