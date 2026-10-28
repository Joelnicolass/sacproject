class_name RtsUnitOrder
extends RefCounted

## What one unit was told to do: the order of its group, cut to its own place. RtsOrders makes one per
## unit and hands it to RtsUnit.give; the game reads it in RtsUnit.order_started and moves, fights or
## follows. Points are kit points (RtsSpace: the ground is XZ; a 2D game reads `spot_2d()`).

## The command's id (`type.id`).
var command: StringName = &""
var type: RtsCommandType
## The body to act on (an enemy, a guarded friend, the side's anchor), or null.
var target: Node
## The order's point: the target where it stood when the order was given, else the clicked point.
var point := Vector3.ZERO
## This unit's place in the formation, (right, forward) in world units from the base.
var slot := Vector2.ZERO
## The yaw the formation is turned by (the camera's, or the guarded body's).
var facing := 0.0
## The formation the group stood in.
var formation: StringName = &""
## True when it waited in the queue behind another order (Shift).
var queued := false


func _init(
	p_type: RtsCommandType = null,
	p_target: Node = null,
	p_point := Vector3.ZERO,
	p_slot := Vector2.ZERO,
	p_facing := 0.0,
	p_formation: StringName = &""
) -> void:
	type = p_type
	command = p_type.id if p_type else &""
	target = p_target
	point = p_point
	slot = p_slot
	facing = p_facing
	formation = p_formation


## True while the order still has the target it was given (a freed target leaves only the point).
func has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


## Where this unit should stand now: its slot around the target's current place (a guarded body that
## walks carries its guards along) or around the order's point.
func spot() -> Vector3:
	var base := RtsSpace.position_of(target) if has_target() else point
	return base + RtsSpace.right(facing) * slot.x + RtsSpace.ahead(facing) * slot.y


## `spot()` as a 2D world point.
func spot_2d() -> Vector2:
	return RtsSpace.to_2d(spot())


## The same command on the same target as `other`: a game may only refresh the point and skip the
## work a new order costs (an AI that repeats a follow order every time its leader moves).
func is_repeat_of(other: RtsUnitOrder) -> bool:
	return other != null and other.command == command and other.target == target
