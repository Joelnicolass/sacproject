class_name RtsPing3D
extends Node3D

## The mark an order leaves where it was given, in a 3D world: a ring on the ground that grows and
## fades, tinted by the command's `tone`. Local only. It listens to an RtsOrderInput, or a game calls
## `play`. Replace its look by giving it a child MeshInstance3D named `Mark` (it scales and fades it).

@export var order_input: RtsOrderInput
@export var seconds := 0.6
@export var radius := 0.8
@export var grow := 1.6
@export var lift := 0.05

var _mark: MeshInstance3D
var _material: StandardMaterial3D
var _tween: Tween


func _ready() -> void:
	_mark = get_node_or_null(^"Mark") as MeshInstance3D
	if _mark == null:
		_mark = MeshInstance3D.new()
		_mark.name = &"Mark"
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 0.8
		ring.outer_radius = radius
		ring.rings = 24
		ring.ring_segments = 8
		_mark.mesh = ring
		add_child(_mark)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	_mark.material_override = _material
	_mark.visible = false
	if order_input:
		order_input.ordered.connect(_on_ordered)


## Shows the mark at `point` (a kit point) in `tone`.
func play(point: Vector3, tone := Color.WHITE) -> void:
	if _tween:
		_tween.kill()
	_mark.global_position = point + Vector3.UP * lift
	_mark.scale = Vector3.ONE
	_material.albedo_color = tone
	_mark.visible = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_mark, "scale", Vector3.ONE * grow, seconds)
	_tween.tween_property(_material, "albedo_color:a", 0.0, seconds)
	_tween.chain().tween_callback(func() -> void: _mark.visible = false)


func _on_ordered(command: StringName, point: Vector3, _target: Node) -> void:
	var type := (
		order_input.orders.commands.find(command)
		if order_input.orders and order_input.orders.commands
		else null
	)
	play(point, type.tone if type else Color.WHITE)
