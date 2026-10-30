class_name QuakeRing
extends FxScene

## The look of a Quake wave: a ring of earth drawn on the ground that goes out with the wave and
## fades. Placeholder look: MIX (alpha blend), never additive. One event (FxBus.broadcast_scene, one
## RPC); presentation only, never headless. It frees itself. Its clock is MatchClock (ticks), like
## the wave it shows: a paused match freezes it, a capture does not make it run ahead. Its child
## Ground (quake_ground.tscn, on_clients_only) bends the land on a client the way the server's
## QuakeWave does; on the server, alone or on the host it does nothing (the real one plays there).
## It does not stun nor decide anything.

## Segments of the ring (each follows the land under it).
@export_range(8, 128) var segments := 64
## The dirt color of the crest and its opacity at the start.
@export var color := Color(0.36, 0.26, 0.16, 0.85)
## Height over the land (m): above the blades of grass, or the ring sinks in them.
@export var lift := 0.8

var _wave_range := 50.0
var _wave_s := 0.5
var _born := 0
var _age := 0.0
var _playing := false

@onready var _mesh: MeshInstance3D = %Ring


## `params`: range (m), seconds (the wave's length), band (m, the width the wave stuns).
func play(params: Dictionary) -> void:
	_wave_range = float(params.get("range", _wave_range))
	_wave_s = maxf(0.01, float(params.get("seconds", _wave_s)))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	_mesh.material_override = material
	_born = MatchClock.now()
	_age = 0.0
	_playing = true
	_redraw()


func _process(_delta: float) -> void:
	if not _playing:
		return
	_age = float(MatchClock.now() - _born) / float(MatchClock.TICKS_PER_SECOND)
	if _age >= _wave_s:
		_playing = false
		queue_free()
		return
	_redraw()


func _redraw() -> void:
	var progress := clampf(_age / _wave_s, 0.0, 1.0)
	var radius := _wave_range * progress
	var width := (0.15 + 0.65 * (1.0 - progress) * (1.0 - progress)) * _wave_range * 0.25
	var inner := maxf(0.0, radius - width * 0.5)
	var outer := radius + width * 0.5
	var tint := color
	tint.a *= (1.0 - progress * progress)
	var shape := Terrain.of(self)
	var center := global_position
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(tint)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p00 := _point(shape, center, inner, a0)
		var p01 := _point(shape, center, outer, a0)
		var p10 := _point(shape, center, inner, a1)
		var p11 := _point(shape, center, outer, a1)
		for v in [p00, p01, p10, p10, p01, p11]:
			st.set_color(tint)
			st.add_vertex(v)
	_mesh.mesh = st.commit()
	_mesh.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)


## A point of the ring in world space, on the land (a hole keeps the center's height).
func _point(shape: Terrain, center: Vector3, radius: float, angle: float) -> Vector3:
	var p := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
	p.y = center.y
	if shape != null:
		var land := shape.height_at(p.x, p.z)
		if not is_nan(land):
			p.y = land
	p.y += lift
	return p
