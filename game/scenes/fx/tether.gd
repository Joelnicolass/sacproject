@tool
class_name Tether
extends MeshInstance3D

## Electric rope between two points that sags and lags like a damped spring (sacengine SacDocTether,
## state.d:15556-15613; mesh makeLineMeshes sacobject.d:2189-2227, 4446-4459; render renderer.d:1678-1703).
## Five control points: P0 at `start`, P1 along the start's `start_axis` by `elbow` meters, P4 at `end`;
## P2 and P3 are masses on a spring (state.d:15577-15600). The rope is a tube of 3 planes at 120 degrees
## with pointed ends, drawn additive from the `ltn2` atlas with the brightness pulse of renderer.d:1688.
## The Sac Doctor's carry uses it with the elbow; the ritual (RFC-020d) uses it with `elbow = 0`.
## Presentation only: it moves nothing. Remove the node to switch it off.
## Mesh and material are made here from the cache and are not stored in the scene.

const CORNERS := 4
const UV_INSET := 0.5 / 64.0

## Where the rope starts (the doctor's needle).
@export var start: Node3D
## Where it ends (the center of the creature). Without it the rope is hidden (in the editor: a preview).
@export var end: Node3D
## Axis of `start` along which the rope leaves first. Godot +Z = the doctor's forward.
@export var start_axis := Vector3.BACK
## Meters the rope leaves along the axis before it heads for `end`. sacengine needleExpansion 1.5;
## 0 = no elbow (the ritual tethers use NaN: state.d:15563).
@export_range(0.0, 5.0, 0.05) var elbow := 1.5

@export_group("Shape")
## Segments of the tube. sacengine 19 (renderer.d numSegments, sacobject.d:4446).
@export_range(4, 64) var segments := 19
## Distance from the axis to each of the 3 planes, meters. sacengine 0.3.
@export_range(0.01, 2.0, 0.01) var radius := 0.3

@export_group("Spring")
## a = gain * |d|^exponent * d (state.d:15580).
@export var spring_gain := 120.0
@export var spring_exponent := 2.0 / 7.0
## Fraction of the speed that remains after 1 s. sacengine exp(log(0.25)/60) per tick.
@export_range(0.0, 1.0, 0.01) var damping_per_s := 0.25
## Cap of the speed relative to the needle, m/s (state.d:15594).
@export var max_relative_speed := 20.0

@export_group("Look")
## Atlas tag (4x4) of the rope, imported by tools/import_ui.py.
@export var atlas_tag := "ltn2"
## sacengine: 0.375 + 14.625 * (...) = between 0.375 and 15 (renderer.d:1688-1690).
@export var energy_min := 0.375
@export var energy_max := 15.0
## Multiplies the whole brightness. 1 = sacengine's numbers.
@export_range(0.0, 4.0, 0.01) var energy_scale := 1.0
@export var pulse := true
@export_range(0.005, 0.5, 0.001) var frame_s := 2.0 / 60.0
@export var fallback_color := Color(0.4, 0.8, 1.0)

var _material: ShaderMaterial
var _missing := false
var _imesh: ImmediateMesh
var _loc: Array[Vector3] = []
var _vel: Array[Vector3] = []
var _live := false
var _started := false


func _ready() -> void:
	_started = true
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	if not BodyCatalog.loads_meshes():
		visible = false
		set_process(false)
		set_physics_process(false)
		return
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_build_material()
	for i in 5:
		_loc.append(Vector3.ZERO)
		_vel.append(Vector3.ZERO)


func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		property.usage &= ~PROPERTY_USAGE_STORAGE
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if start == null:
		warnings.append("Asigná en `start` el nodo donde empieza la cuerda (la aguja del doctor).")
	if _missing:
		warnings.append("Falta el atlas `%s.png` en assets/original/fx/ (tools/import_ui.py): se dibuja un relleno." % atlas_tag)
	return warnings


## Forgets the lag: the next frame puts the rope straight between its ends.
func reset() -> void:
	_live = false


func _physics_process(delta: float) -> void:
	var targets := _targets()
	if targets.is_empty():
		_live = false
		visible = false
		return
	visible = true
	if not _live:
		for i in 5:
			_loc[i] = targets[i]
			_vel[i] = Vector3.ZERO
		_live = true
		return
	_step(targets, delta)


func _process(_delta: float) -> void:
	if _imesh == null:
		return
	if Engine.is_editor_hint():
		# The editor does not run physics: place the rope here so the scene shows something.
		_physics_process(1.0 / 60.0)
	if Engine.is_editor_hint():
		_push_params()
	_imesh.clear_surfaces()
	if not _live:
		return
	_draw()


## The 5 wanted points, or empty if the rope has nothing to join.
func _targets() -> PackedVector3Array:
	var out := PackedVector3Array()
	if start == null or not is_instance_valid(start) or not start.is_inside_tree():
		return out
	var p0 := start.global_position
	var axis := (start.global_basis * start_axis).normalized()
	var p_end: Vector3
	if end != null and is_instance_valid(end) and end.is_inside_tree():
		p_end = end.global_position
	elif Engine.is_editor_hint():
		p_end = p0 - axis * 3.0 + Vector3(0.0, 2.0, 0.0)
	else:
		return out
	out.resize(5)
	out[0] = p0
	# sacengine getSacDocTetherTargetLocations (state.d:15556-15567): the points after the first are
	# i/intp * center + (intp - i)/intp * first.
	if elbow > 0.0:
		var first := p0 + elbow * axis
		for i in 4:
			out[1 + i] = (i / 3.0) * p_end + ((3.0 - i) / 3.0) * first
	else:
		for i in 5:
			out[i] = (i / 4.0) * p_end + ((4.0 - i) / 4.0) * p0
	return out


func _step(targets: PackedVector3Array, delta: float) -> void:
	var total := 0.5 * ((targets[0] - _loc[0]) + (targets[1] - _loc[1])) / maxf(delta, 0.0001)
	_loc[0] = targets[0]
	_loc[1] = targets[1]
	_loc[4] = targets[4]
	var damp := pow(damping_per_s, delta)
	for i in range(2, 4):
		var d := targets[i] - _loc[i]
		var a := spring_gain * pow(d.length_squared(), spring_exponent * 0.5) * d
		_vel[i] += a * delta
		_vel[i] *= damp
		var relative := _vel[i] - total
		if relative.length_squared() > max_relative_speed * max_relative_speed:
			_vel[i] = total + max_relative_speed / relative.length() * relative
		_loc[i] += _vel[i] * delta


## Hermite curve through the 5 points like sacengine cintp (util.d:562): point and tangent at t in 0..1.
func _curve(t: float) -> Array[Vector3]:
	var n := 5
	var i := maxi(0, mini(int(floor(t * (n - 1))), n - 2))
	var u := clampf(t * (n - 1) - i, 0.0, 1.0)
	var p0 := _loc[i]
	var p1 := _loc[i + 1]
	var m0 := _loc[mini(i + 1, n - 1)] - _loc[maxi(0, i - 1)]
	var m1 := _loc[mini(i + 2, n - 1)] - _loc[i]
	var u2 := u * u
	var u3 := u2 * u
	var p := (2 * u3 - 3 * u2 + 1) * p0 + (u3 - 2 * u2 + u) * m0 + (-2 * u3 + 3 * u2) * p1 + (u3 - u2) * m1
	var m := (6 * u2 - 6 * u) * p0 + (3 * u2 - 4 * u + 1) * m0 + (-6 * u2 + 6 * u) * p1 + (3 * u2 - 2 * u) * m1
	return [p, m]


func _draw() -> void:
	var count := segments + 1
	var centers: Array[Vector3] = []
	var offsets: Array = []
	var sqrt34 := sqrt(0.75)
	var base := [Vector3(0, -1, 0) * radius, Vector3(sqrt34, 0.5, 0) * radius, Vector3(-sqrt34, 0.5, 0) * radius]
	for i in count:
		var c := _curve(float(i) / float(count - 1))
		centers.append(c[0])
		var tangent: Vector3 = c[1].normalized() if c[1].length_squared() > 0.000001 else Vector3.BACK
		var q := Quaternion(Vector3.BACK, tangent)
		offsets.append([q * base[0], q * base[1], q * base[2]])
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for j in 3:
			var pos: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in CORNERS:
				var bone := i + 1 if (k == 1 or k == 2) else i
				var p: Vector3 = centers[bone]
				var pointy := bone == 0 or bone == segments
				if (k == 2 or k == 3) and not pointy:
					p += offsets[bone][j]
				pos.append(p)
				# makeLineMesh: u flips per segment, v is the centerline (bright) for k 0 and 1.
				var flip := ((i & 1) == 1) != (k == 1 or k == 2)
				var u := 1.0 - UV_INSET if flip else UV_INSET
				var v := 1.0 - UV_INSET if (k == 0 or k == 1) else UV_INSET
				uvs.append(Vector2(u, v))
			for idx in [0, 1, 2, 2, 3, 0]:
				_imesh.surface_set_uv(uvs[idx])
				_imesh.surface_add_vertex(pos[idx])
	_imesh.surface_end()


func _build_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://scenes/fx/tether.gdshader")
	var texture := FxAtlas.texture(atlas_tag)
	_missing = texture == null
	_material.set_shader_parameter("use_textures", not _missing)
	_material.set_shader_parameter("atlas", texture)
	_push_params()
	material_override = _material
	update_configuration_warnings()


func _push_params() -> void:
	_material.set_shader_parameter("fallback_color", fallback_color)
	_material.set_shader_parameter("energy_min", energy_min)
	_material.set_shader_parameter("energy_max", energy_max)
	_material.set_shader_parameter("energy_scale", energy_scale)
	_material.set_shader_parameter("pulse", pulse)
	_material.set_shader_parameter("frame_s", frame_s)
