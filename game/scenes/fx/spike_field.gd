class_name SpikeField
extends FxScene

## F151 (RFC-030 030n-b): the Rhinok's spikes, sacengine Spike (state.d:3875-3885; updateSpike 20473-20478; placeSpike
## 25008-25015), drawn as renderer.d:2627-2638 draws them: SacSpike (sacobject.d:2984-2994), the mesh of
## makeSpikeMesh(32, 0.6, 0.75, 0.3, 0.25) (a ring of radius 0.3 on the ground, 0.25 at 0.75, the tip at 1) with the
## texture jspk (shwn.WAD jams/text, tools/import/fx_catalog.py). Model matrix: translate · scale(s, s, s·d.z) · shear(d.x/d.z,
## d.y/d.z), that is the spike's axis is s·d, d = ((0, 0, height) + a point of the disk of radius `tilt`) · U(0.85, 1.15);
## s = 1 − (2·t/lifetime − 1)²: it rises out of the ground and sinks back in 2/3 s.
## One event (FxBus.broadcast_scene, one RPC) is many spikes: `count` of them drawn evenly over the area of the annulus
## [inner, outer] around this node, each on the land under it (a spike off the land is not placed, as placeSpike).
## Presentation only: every peer, never headless; its generator is seeded by the event (`seed`), never the global one.

## How long a spike stands.
## Ref: sacengine Spike.lifetime, 2·60/3 updates.
@export var lifetime_s := 0.6666
## sacengine uniformDisk(…, 2.0): how far the tip leans (m).
@export var tilt := 2.0
## makeSpikeMesh: radius at the ground, radius and height of the neck (the tip is at 1).
@export var base_radius := 0.3
@export var neck_radius := 0.25
@export var neck_height := 0.75
## Sides of the mesh (sacengine 32).
@export_range(3, 32) var sides := 12
## The spike texture (jspk.png in spike_field.tscn). Empty = a flat `fallback_color`.
@export var texture: Texture2D
@export var fallback_color := Color(0.4, 0.3, 0.2, 1)

@onready var _spikes: MultiMeshInstance3D = %Spikes

## Per spike: its axis at full size (s·d with s = 1).
var _axes: PackedVector3Array = PackedVector3Array()
var _bases: PackedVector3Array = PackedVector3Array()
var _age := 0.0
var _playing := false

static var _mesh_cache: Dictionary = {}


## `params`: inner, outer (m), count, height (sacengine spikeHeight: 2 on the way, 2,5 in the rings), seed; `life` (s)
## overrides lifetime_s.
func play(params: Dictionary) -> void:
	var inner := float(params.get("inner", 0.0))
	var outer := float(params.get("outer", 1.0))
	var count := int(params.get("count", 0))
	var height := float(params.get("height", 2.5))
	lifetime_s = float(params.get("life", lifetime_s))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(params.get("seed", 0))
	var shape := GroundSurface.of(self)
	var center := global_position
	for i in count:
		var angle := rng.randf() * TAU
		var radius := sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
		var base := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		if shape != null:
			var land := shape.height_at(base.x, base.z)
			if is_nan(land):
				continue
			base.y = land
		var lean := sqrt(rng.randf()) * tilt
		var lean_angle := rng.randf() * TAU
		var axis := Vector3(cos(lean_angle) * lean, height, sin(lean_angle) * lean) * rng.randf_range(0.85, 1.15)
		_bases.append(base - center)
		_axes.append(axis)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = spike_mesh(sides, base_radius, neck_radius, neck_height)
	multimesh.instance_count = _bases.size()
	_spikes.multimesh = multimesh
	_spikes.material_override = spike_material(texture, fallback_color)
	_age = 0.0
	_playing = true
	_pose()


func _process(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	if _age >= lifetime_s:
		_playing = false
		queue_free()
		return
	_pose()


func _pose() -> void:
	var t := 2.0 * _age / maxf(lifetime_s, 0.001) - 1.0
	var s := maxf(0.0, 1.0 - t * t)
	var multimesh := _spikes.multimesh
	for i in _bases.size():
		var basis := Basis(Vector3(s, 0.0, 0.0), _axes[i] * s, Vector3(0.0, 0.0, s))
		multimesh.set_instance_transform(i, Transform3D(basis, _bases[i]))


## The material of a spike: `albedo` (jspk) lit, or `fallback` when there is none. The Wall of Spikes draws its own with it.
static func spike_material(albedo: Texture2D, fallback: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if albedo:
		material.albedo_texture = albedo
	else:
		material.albedo_color = fallback
	return material


## makeSpikeMesh(numV, texBase 0.6, base, baseRadius, topRadius) with numU 2: the ground ring, the neck ring and the tip
## (y up); texture coordinates radial, as sacengine's.
static func spike_mesh(sides: int, base_radius: float, neck_radius: float, neck_height: float) -> ArrayMesh:
	var key := "%d/%s/%s/%s" % [sides, base_radius, neck_radius, neck_height]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [[base_radius, 0.0, 0.5], [neck_radius, neck_height, 0.5 * (1.0 - 0.6)]]
	for j in sides:
		var a0 := TAU * float(j) / float(sides)
		var a1 := TAU * float(j + 1) / float(sides)
		var p := []
		for ring: Array in rings:
			var r: float = ring[0]
			p.append([Vector3(r * cos(a0), ring[1], r * sin(a0)), _uv(a0, ring[2]), Vector3(r * cos(a1), ring[1], r * sin(a1)), _uv(a1, ring[2])])
		_tri(st, p[0][0], p[0][1], p[1][0], p[1][1], p[0][2], p[0][3])
		_tri(st, p[0][2], p[0][3], p[1][0], p[1][1], p[1][2], p[1][3])
		_tri(st, p[1][0], p[1][1], Vector3(0.0, 1.0, 0.0), Vector2(0.5, 0.5), p[1][2], p[1][3])
	st.generate_normals()
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _uv(angle: float, radius: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	dir /= maxf(absf(dir.x), absf(dir.y))
	return Vector2(0.5, 0.5) + dir * radius


static func _tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
