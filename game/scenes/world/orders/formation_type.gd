class_name FormationType
extends Resource

## A formation of a group order (RFC-038, sacengine Formation / getFormationOffsets, state.d:417). A type resource: it
## never changes during a match; the formation a creature keeps is a StringName on its UnitOrders.

const UnitOrders := preload("res://scenes/world/units/unit_orders.gd")

@export var id: StringName = &""
## UI text (Spanish).
@export var display_name := ""
## The icon of the radial menu entry (RFC-038 038c).
@export var icon: Texture2D


## Slots (right, forward) in meters for `count` bodies. `spacing` is the distance between two neighbors,
## `target_distance` the distance from a guarded or attacked body (0 = no target), `command` a UnitOrders.Command.
func slots(_count: int, _spacing: float, _target_distance: float, _command: int) -> Array[Vector2]:
	return []


## Rows the formation lays `count` bodies in (1 = a single line).
func row_count(_count: int) -> int:
	return 1


## Bodies per row for the row-wise slot match of Orders; 0 = the greedy match (a single row).
func match_row_size(_count: int) -> int:
	return 0


## Width of the widest row, for debug overlays.
func row_width(count: int, spacing: float) -> float:
	var left := 0.0
	var right := 0.0
	for slot in slots(count, spacing, 0.0, UnitOrders.Command.MOVE):
		left = minf(left, slot.x)
		right = maxf(right, slot.x)
	return right - left
