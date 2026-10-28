@tool
class_name TeleportRings
extends Node3D

## The blue rings of a body that jumps, at the origin (it goes up) or at the destination (it comes
## down). For `teleport_effect_s`
## a ring is born each frame at a height that moves in steps along the body (up_steps / down_steps), lives
## `teleport_ring_s`, rises a little, shrinks with sqrt(1 - age) and glows with 20 * scale². One MultiMesh draws them all;
## it frees itself when the last ring is gone. Presentation: it is never created on the dedicated server.
## The atlas `brng` comes from the local install through tools/import/import_ui.py (assets/original/fx).

## Where the ring height jumps, as (frame as a fraction of the effect, change in body heights).
const UP_STEPS: Array[Vector2] = [Vector2(0.0, 0.8), Vector2(0.2, -0.6), Vector2(0.6, -0.8)]
const DOWN_STEPS: Array[Vector2] = [Vector2(0.0, 0.4), Vector2(0.4, 0.8), Vector2(0.8, 0.6)]
## The mesh side of a ring of scale 1: makeSpriteMeshes(4, 4, 28, 28) scaled by 0.08.
const MESH_SIDE := 28.0 * 0.08
const RING_ENERGY := 20.0
const ATLAS_FRAMES := 16
## Ticks per atlas frame.
const TICKS_PER_ATLAS_FRAME := 8.0

@export var rules: MatchRules
## Atlas of the ring (`brng`, 4x4 frames).
@export var atlas: Texture2D
@export var rings: MultiMeshInstance3D

var _going_out := true
var _width := 1.0
var _height := 1.0
var _t := 0.0
var _steps := 0
var _spawn_z := PackedFloat32Array()
var _ring_ticks := 48.0
var _rise := 0.25


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if rules == null:
		warnings.append("Assign in `rules` the MatchRules (the rings' duration).")
	if rings == null:
		warnings.append("Assign in `rings` the MultiMeshInstance3D that draws them.")
	return warnings


## Height over the feet of the ring born at `frame`, in body heights (replayed from frame 0).
static func ring_height(going_out: bool, frame: int, steps: int) -> float:
	var table := UP_STEPS if going_out else DOWN_STEPS
	var z := 0.0
	for f in range(frame + 1):
		for step in table:
			if f == floori(step.x * float(steps)):
				z += step.y
		z += (1.0 if going_out else -1.0) / float(steps)
	return z


## Start at `feet` (the bottom center of the body box). `width` is max(size.x, size.y) of the box.
func start(going_out: bool, feet: Vector3, width: float, height: float) -> void:
	global_position = feet
	_going_out = going_out
	_width = width
	_height = height
	_ring_ticks = rules.teleport_ring_s * MatchClock.TICKS_PER_SECOND_F if rules != null else 48.0
	_rise = rules.teleport_ring_rise if rules != null else 0.25
	_steps = maxi(
		1,
		roundi(
			(
				(rules.teleport_effect_s if rules != null else 32.0 / 60.0)
				* MatchClock.TICKS_PER_SECOND_F
			)
		)
	)
	_spawn_z.resize(_steps)
	for f in _steps:
		_spawn_z[f] = ring_height(going_out, f, _steps) * height
	var texture := atlas
	if rings == null or texture == null:
		queue_free()
		return
	var material := rings.material_override as ShaderMaterial
	material.set_shader_parameter("atlas", texture)
	rings.multimesh.instance_count = _steps
	_t = 0.0
	_update()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _spawn_z.is_empty():
		return
	_t += delta * MatchClock.TICKS_PER_SECOND_F
	if _t >= float(_steps) + _ring_ticks:
		queue_free()
		return
	_update()


func _update() -> void:
	var multimesh := rings.multimesh
	for f in _steps:
		var age := _t - float(f)
		if age < 0.0 or age >= _ring_ticks:
			multimesh.set_instance_transform(
				f, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
			)
			continue
		var life := age / _ring_ticks
		var ring_scale := _width * sqrt(1.0 - life)
		var rise := _rise * life
		multimesh.set_instance_transform(
			f,
			Transform3D(
				Basis.from_scale(Vector3.ONE * ring_scale), Vector3(0.0, _spawn_z[f] + rise, 0.0)
			)
		)
		var glow := RING_ENERGY * ring_scale * ring_scale
		multimesh.set_instance_color(f, Color(glow, glow, glow, 1.0))
		var frame := floori(age / TICKS_PER_ATLAS_FRAME) % ATLAS_FRAMES
		multimesh.set_instance_custom_data(
			f, Color(0.0, 0.0, (float(frame) + 0.01) / float(ATLAS_FRAMES), 0.0)
		)
