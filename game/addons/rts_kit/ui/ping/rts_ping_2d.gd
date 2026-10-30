class_name RtsPing2D
extends Node2D

## The mark an order leaves where it was given, in a 2D world: a circle that grows and fades, tinted
## by the command's `tone`. Local only. It listens to an RtsOrderInput, or a game calls `play`.

@export var order_input: RtsOrderInput
@export var seconds := 0.6
@export var radius := 12.0
@export var grow := 1.8
@export var width := 2.5

var _color := Color.WHITE
var _scale := 1.0
var _alpha := 0.0
var _tween: Tween


func _ready() -> void:
	if order_input:
		order_input.ordered.connect(_on_ordered)


## Shows the mark at `point` (a kit point) in `tone`.
func play(point: Vector3, tone := Color.WHITE) -> void:
	if _tween:
		_tween.kill()
	global_position = RtsSpace.to_2d(point)
	_color = tone
	_scale = 1.0
	_alpha = 1.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_scale", grow, seconds)
	_tween.tween_property(self, "_alpha", 0.0, seconds)
	_tween.tween_method(func(_v: float) -> void: queue_redraw(), 0.0, 1.0, seconds)


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var color := _color
	color.a *= _alpha
	draw_arc(Vector2.ZERO, radius * _scale, 0.0, TAU, 32, color, width, true)


func _on_ordered(command: StringName, point: Vector3, _target: Node) -> void:
	var type := (
		order_input.orders.commands.find(command)
		if order_input.orders and order_input.orders.commands
		else null
	)
	play(point, type.tone if type else Color.WHITE)
