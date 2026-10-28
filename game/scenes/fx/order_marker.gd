class_name OrderMarker
extends Node3D

## The mark an order leaves on the ground: a narrow 8-sided cone, apex on the ordered point, drawn with the `aura` texture plus 8 white
## shells that turn against each other. It lasts 0.5 s: alpha 1 - t, width grows to 3x and height to 1.25x. White for a
## move or retreat, blue for guard, red for attack and advance. Client-local presentation: no RPC, never in headless.
## One instance is reused (`play` restarts it), so no node is created or freed per order.

enum Tone { WHITE, RED, BLUE }

const TINTS := [Color(1.0, 1.0, 1.0), Color(1.0, 0.05, 0.05), Color(0.05, 0.05, 1.0)]
const SIDES := 8
const SHELLS := 8
const SHELL_SHRINK := 0.95
const CONE_HEIGHT := 10.0
const CONE_RADIUS := 0.7

static var _cone_mesh: ArrayMesh

## Seconds the mark lasts.
@export_range(0.05, 3.0, 0.05, "suffix:s") var lifetime_s := 0.5
## Overall size multiplier (1 = a 10 m by 0.7 m cone).
@export_range(0.1, 4.0, 0.05) var size_scale := 1.0
## Extra tint multiplied over the tone's color (white = the tone's own color).
@export var color := Color.WHITE
## The texture of the cone (aura.png in order_marker.tscn). Empty = the cone reads plain white, like the shells.
@export var aura: Texture2D
## Meters over the ground, so the apex does not z-fight the land.
@export var lift := 0.1

var _age := 0.0
var _playing := false
var _cone: MeshInstance3D
var _shells: Array[MeshInstance3D] = []
var _cone_material: ShaderMaterial
var _shell_material: ShaderMaterial
var _tone := Tone.WHITE


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void: physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	visible = false
	set_process(false)
	if DisplayServer.get_name() == "headless":
		return
	_build()


## Shows the mark at `point` in the tone of the order, restarting it if it is still playing.
func play(point: Vector3, tone: Tone = Tone.WHITE) -> void:
	global_position = point + Vector3(0.0, lift, 0.0)
	if _cone == null:
		return
	_tone = tone
	_apply_tone()
	_age = 0.0
	_playing = true
	_update(0.0)
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	if _age >= lifetime_s:
		_playing = false
		visible = false
		set_process(false)
		return
	_update(_age / lifetime_s)


func _build() -> void:
	var shader := load("res://scenes/fx/order_marker.gdshader") as Shader
	_cone_material = ShaderMaterial.new()
	_cone_material.shader = shader
	_cone_material.set_shader_parameter("aura", aura)
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = shader
	var mesh := _mesh()
	_cone = _instance(mesh, _cone_material)
	for _i in SHELLS:
		_shells.append(_instance(mesh, _shell_material))


func _instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Cone with the apex at the origin and the ring `CONE_HEIGHT` up (y is up).
static func _mesh() -> ArrayMesh:
	if _cone_mesh != null:
		return _cone_mesh
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in SIDES:
		var angle := TAU * i / SIDES
		vertices.append(Vector3(CONE_RADIUS * cos(angle), CONE_HEIGHT, CONE_RADIUS * sin(angle)))
		uvs.append(Vector2(0.5, 0.5) + 0.5 * Vector2(cos(angle), sin(angle)))
	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))
	var indices := PackedInt32Array()
	for i in SIDES:
		indices.append_array([i, SIDES, (i + 1) % SIDES])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_cone_mesh = ArrayMesh.new()
	_cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _cone_mesh


func _apply_tone() -> void:
	var base: Color = TINTS[_tone]
	var energy := 0.4 * pow(3.0 / (base.r + base.g + base.b), 4.0)
	var tint := Color(base.r * color.r, base.g * color.g, base.b * color.b)
	for material in [_cone_material, _shell_material]:
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("energy", energy)


## `t` in 0..1 of the life: the cone grows, the shells turn the other way each.
func _update(t: float) -> void:
	var horizontal := 1.0 + 2.0 * t
	var vertical := 1.0 + 0.25 * t
	var alpha := (1.0 - t) * color.a
	_cone_material.set_shader_parameter("alpha", alpha)
	_shell_material.set_shader_parameter("alpha", alpha)
	_cone.scale = Vector3(horizontal, vertical, horizontal) * size_scale
	_cone.rotation.y = 0.0
	for k in SHELLS:
		horizontal *= SHELL_SHRINK
		var node := _shells[k]
		node.scale = Vector3(horizontal, vertical, horizontal) * size_scale
		node.rotation.y = (-1.0 if k & 1 else 1.0) * TAU * t * (k + 1)
