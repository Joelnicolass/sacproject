@tool
class_name GuardianTether
extends Node3D

## The beam between a guardian and its building (RFC-021b), drawn on every peer with a window; the
## dedicated server never instantiates it. GuardianBond creates it when `post_path` changes and calls
## retire() when it empties. Port of sacengine's: 19 segments, a wobbly line of 5 control points that
## reshapes every second (updateGuardianShape, state.d:15326-15340), it grows from the creature to the
## building in a second (cubic, state.d:15400-15402), pulses at 0.75-1 of its width (renderer.d:1716)
## and withdraws in a second, toward the building if the creature is gone or toward the creature if the
## building is (state.d:15404-15417).
## Look: the tube of 3 planes with pointed ends that sacengine draws (makeLineMeshes(19, 4, 4, 1.5, 1.0,
## pointy), sacobject.d:4466-4472), additive and shadeless with energy 5 (renderer.d:253-261), from the
## `grdn` atlas (charlie.wad, sacobject.d:4466) that tools/import/import_ui.py puts in assets/original/fx/. One
## cell of the 4x4 per 2 ticks (16 cells). Without the atlas it falls back to a flat soft color.
## The beam waits for the building while `post_path` is set and the building has not arrived on this peer
## (a late client); it only withdraws when the bond ends (retire()).
## Only presentation: nothing here reads or writes game state.

enum Phase { APPEARING, STEADY, WITHDRAWING_AT_BUILDING, WITHDRAWING_AT_CREATURE }

## Segments of the line (SacGuardianTether.numSegments, sacobject.d:4462).
@export var segments := 19
## Edge of the box the control points wobble in (Guardian.locRadius, state.d:2780); the ends move a quarter of that.
@export var jitter_radius := 0.75
## Distance from the axis to each of the 3 planes, meters (the 1.0 passed to makeLineMeshes, sacobject.d:4472).
@export var width := 1.0
## Atlas tag of the beam (assets/original/fx/<tag>.png).
@export var atlas_tag := "grdn"
## Brightness (SacGuardianTether material energy, renderer.d:257).
@export var energy := 5.0
## Seconds per atlas cell (2 ticks of 60 per second).
@export var frame_s := 2.0 / 60.0
@export var appear_s := 1.0
@export var reshape_s := 1.0
@export var withdraw_s := 1.0
## Pulse period (Guardian.pulseFrames = updateFPS / 2).
@export var pulse_s := 0.5
## Height of the creature's center over its feet.
@export var center_height := 0.9
@export var color := Color(0.35, 1.0, 0.55, 1.0)
## Draws the ribbon. Its material is the look; a missing one warns in the inspector.
@export var beam: MeshInstance3D

var phase := Phase.APPEARING

var _creature: Node3D
var _post_path := NodePath()
var _clock := 0.0
var _phase_clock := 0.0
var _creature_at := Vector3.ZERO
var _building_at := Vector3.ZERO
var _prev: Array[Vector3] = []
var _next: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _shape_cycle := -1
## True once the building has been found on this peer: before that there is nothing to draw toward.
var _building_known := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	top_level = true
	global_transform = Transform3D.IDENTITY
	if beam != null:
		beam.mesh = ImmediateMesh.new()
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_apply_look()
	MatchSeed.seed_rng(_rng, ["tether", String(name)])


func _apply_look() -> void:
	var material := beam.material_override as ShaderMaterial
	if material == null:
		return
	material = material.duplicate()
	beam.material_override = material
	var texture := FxAtlas.texture(atlas_tag)
	material.set_shader_parameter("use_textures", texture != null)
	material.set_shader_parameter("atlas", texture)
	material.set_shader_parameter("fallback_color", color)
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("frame_s", frame_s)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if beam == null:
		warnings.append("Asigná en `beam` el MeshInstance3D que dibuja el haz (con su material).")
	return warnings


## Starts the beam from `creature` to the GuardPost at `post_path`.
func follow(creature: Node3D, post_path: NodePath) -> void:
	_creature = creature
	_post_path = post_path
	phase = Phase.APPEARING
	_phase_clock = 0.0
	_sample()


## The bond ended: the beam withdraws and frees itself.
func retire() -> void:
	if phase == Phase.WITHDRAWING_AT_BUILDING or phase == Phase.WITHDRAWING_AT_CREATURE:
		return
	_sample()
	phase = Phase.WITHDRAWING_AT_BUILDING if _building_known and _post() != null else Phase.WITHDRAWING_AT_CREATURE
	_phase_clock = 0.0


## Where the two ends are at `progress` (0..1) of the current phase: creature end, building end.
static func ends(phase_now: Phase, progress: float, creature_at: Vector3, building_at: Vector3) -> Array[Vector3]:
	match phase_now:
		Phase.APPEARING:
			var eased := pow(clampf(progress, 0.0, 1.0), 3.0)
			return [creature_at, creature_at.lerp(building_at, eased)]
		Phase.WITHDRAWING_AT_BUILDING:
			return [creature_at.lerp(building_at, clampf(progress, 0.0, 1.0)), building_at]
		Phase.WITHDRAWING_AT_CREATURE:
			return [creature_at, building_at.lerp(creature_at, clampf(progress, 0.0, 1.0))]
	return [creature_at, building_at]


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or beam == null:
		return
	_clock += delta
	_phase_clock += delta
	_sample()
	if not _building_known:
		## A late client: the building has not been replicated yet. Wait for it while the bond stands.
		if phase == Phase.WITHDRAWING_AT_CREATURE or phase == Phase.WITHDRAWING_AT_BUILDING:
			queue_free()
			return
		_phase_clock = 0.0
		(beam.mesh as ImmediateMesh).clear_surfaces()
		return
	if phase == Phase.APPEARING and _phase_clock >= appear_s:
		phase = Phase.STEADY
	if (phase == Phase.WITHDRAWING_AT_BUILDING or phase == Phase.WITHDRAWING_AT_CREATURE) and _phase_clock >= withdraw_s:
		queue_free()
		return
	var span := appear_s if phase == Phase.APPEARING else withdraw_s
	var both := ends(phase, _phase_clock / maxf(span, 0.001), _creature_at, _building_at)
	_draw(both[0], both[1])


func _post() -> GuardPost:
	var node := get_node_or_null(_post_path) as GuardPost if not _post_path.is_empty() and is_inside_tree() else null
	return node if node != null and not node.is_queued_for_deletion() else null


## Remembers where the ends are while they exist: a body that is gone leaves its last place.
func _sample() -> void:
	if _creature != null and is_instance_valid(_creature):
		_creature_at = _creature.global_position + Vector3.UP * center_height
	var post := _post()
	if post != null:
		_building_at = post.attach_position()
		_building_known = true


func _draw(from: Vector3, to: Vector3) -> void:
	var mesh := beam.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var line := to - from
	var length := line.length()
	if length < 0.01:
		return
	var along := line / length
	var side_a := along.cross(Vector3.UP)
	if side_a.length_squared() < 0.0001:
		side_a = along.cross(Vector3.RIGHT)
	side_a = side_a.normalized()
	var side_b := along.cross(side_a)
	var locs := _control_points()
	var pulse := 0.75 + 0.25 * 0.5 * (1.0 + sin(TAU * fposmod(_clock, pulse_s) / pulse_s))
	var points: Array[Vector3] = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var wobble := _spline(locs, t)
		points.append(from + line * t + side_a * wobble.x + side_b * wobble.y + along * wobble.z)
	## 3 planes at 120 degrees (makeLineMesh offsets, sacobject.d:2192), pointed at both ends.
	var root := sqrt(0.75)
	var offsets: Array[Vector3] = [-side_b, side_a * root + side_b * 0.5, -side_a * root + side_b * 0.5]
	var inset := 0.5 / 64.0
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for j in 3:
			var pos: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in 4:
				var bone := i + 1 if (k == 1 or k == 2) else i
				var p := points[bone]
				if (k == 2 or k == 3) and bone != 0 and bone != segments:
					p += offsets[j] * width * pulse
				pos.append(p)
				## makeLineMesh texcoords: u flips per segment, v is the bright centerline for k 0 and 1.
				var flip := ((i & 1) == 1) != (k == 1 or k == 2)
				uvs.append(Vector2(1.0 - inset if flip else inset, 1.0 - inset if (k == 0 or k == 1) else inset))
			for idx in [0, 1, 2, 2, 3, 0]:
				mesh.surface_set_uv(uvs[idx])
				mesh.surface_add_vertex(pos[idx])
	mesh.surface_end()


## The 5 control points (state.d:15326-15340), mixed between the last shape and the next.
func _control_points() -> Array[Vector3]:
	if _next.is_empty():
		_next = _random_shape()
		_prev = _next.duplicate()
	var cycle := int(floor(_clock / reshape_s))
	if cycle != _shape_cycle:
		_shape_cycle = cycle
		_prev = _next
		_next = _random_shape()
	var mix := fposmod(_clock, reshape_s) / reshape_s
	var result: Array[Vector3] = []
	for i in _prev.size():
		result.append(_prev[i].lerp(_next[i], mix))
	return result


func _random_shape() -> Array[Vector3]:
	var shape: Array[Vector3] = []
	var half := jitter_radius * 0.5
	for i in 5:
		var p := Vector3(_rng.randf_range(-half, half), _rng.randf_range(-half, half), _rng.randf_range(-half, half))
		if i == 0 or i == 4:
			p *= 0.25
		shape.append(p)
	return shape


## Catmull-Rom through the control points at t in 0..1.
static func _spline(points: Array[Vector3], t: float) -> Vector3:
	var last := points.size() - 1
	var u := clampf(t, 0.0, 1.0) * last
	var i := mini(int(floor(u)), last - 1)
	var local := u - float(i)
	var p0 := points[maxi(i - 1, 0)]
	var p1 := points[i]
	var p2 := points[i + 1]
	var p3 := points[mini(i + 2, last)]
	return 0.5 * ((2.0 * p1) + (p2 - p0) * local + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * local * local + (3.0 * p1 - p0 - 3.0 * p2 + p3) * local * local * local)
