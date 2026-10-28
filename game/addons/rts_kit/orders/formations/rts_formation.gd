@tool
class_name RtsFormation
extends Resource

## A formation of a group order: where `count` units stand, as slots (right, forward) in world units
## from the order's base. A type resource: it never changes during a match; the formation a unit keeps
## is a StringName on its RtsUnit, and only that id travels over a network. Extend it for a shape of
## your own (override `slots`, and `row_count` / `match_row_size` for rows).

const MOVE := RtsCommandType.Role.MOVE
const ATTACK := RtsCommandType.Role.ATTACK
const GUARD := RtsCommandType.Role.GUARD

@export var id: StringName = &""
## The words for the player (the radial menu's caption).
@export var display_name := ""
## The picture of its radial menu entry (empty: the menu draws its slots as dots).
@export var icon: Texture2D


## Slots (right, forward) for `count` units. `spacing` is the distance between two neighbors,
## `target_distance` the distance from a guarded or attacked body (0 = no target), `role` the
## command's RtsCommandType.Role.
func slots(_count: int, _spacing: float, _target_distance: float, _role: int) -> Array[Vector2]:
	return []


## Rows the formation lays `count` units in (1 = a single line).
func row_count(_count: int) -> int:
	return 1


## Units per row for RtsOrders' row-wise slot match; 0 = the greedy match (a single row).
func match_row_size(_count: int) -> int:
	return 0


## Width of the widest row (debug overlays).
func row_width(count: int, spacing: float) -> float:
	var left := 0.0
	var right := 0.0
	for slot in slots(count, spacing, 0.0, MOVE):
		left = minf(left, slot.x)
		right = maxf(right, slot.x)
	return right - left
