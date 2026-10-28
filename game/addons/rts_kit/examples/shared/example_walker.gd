class_name RtsExampleWalker
extends Node

## The examples' stand-in for a game's unit logic: what the kit leaves to the game. It sits next to an
## RtsUnit, walks its body toward the order's spot (straight, no pathfinding), "attacks" by walking up
## to the target and reporting `complete()`, keeps guarding (it never completes guard orders), and
## shows the selection with a ring. A real game replaces all of this with its own movement and combat.

@export var unit: RtsUnit
## World units per second (meters in 3D, pixels in 2D).
@export var speed := 6.0
## How close counts as there.
@export var arrive := 0.3

var _order: RtsUnitOrder


func _ready() -> void:
	if unit == null:
		unit = get_parent().get_node_or_null(^"RtsUnit") as RtsUnit
	unit.order_started.connect(_on_order_started)
	unit.order_ended.connect(_on_order_ended)
	unit.selected_changed.connect(_on_selected)
	_on_selected(unit.selected)


func _on_order_started(order: RtsUnitOrder, _replaced: RtsUnitOrder) -> void:
	_order = order


func _on_order_ended(order: RtsUnitOrder, _result: StringName) -> void:
	if order == _order:
		_order = null


func _physics_process(delta: float) -> void:
	if _order == null:
		return
	var here := unit.position()
	var goal := _order.spot()
	var flat_goal := Vector3(goal.x, here.y, goal.z)
	var to_goal := flat_goal - here
	var step := speed * delta
	if to_goal.length() <= maxf(arrive, step):
		RtsSpace.place(unit.body, flat_goal)
		if _order.type and _order.type.ends_on_its_own:
			unit.complete()
		return
	RtsSpace.place(unit.body, here + to_goal.normalized() * step)
	_face(to_goal)


func _face(direction: Vector3) -> void:
	var body := unit.body
	if body is Node3D and direction.length_squared() > 0.0001:
		(body as Node3D).rotation.y = RtsSpace.yaw_of_direction(direction)


func _on_selected(on: bool) -> void:
	var ring := unit.body.get_node_or_null(^"Ring") as Node
	if ring is Node3D:
		(ring as Node3D).visible = on
	elif ring is CanvasItem:
		(ring as CanvasItem).visible = on
