class_name RunAway
extends AbilityEffect

## F133 (RFC-030 030v-a): Run Away (!nur: the Flame Minion's, the Silverback's, the Frostwolf's), moved from ActiveAbility's branches without a
## change. The body takes a Speedup (SpeedupEffect, duration ≥ 1 s), stops and drops its orders. Refused while it already has one.

const _SPEEDUP := preload("res://scenes/world/spells/speedup_effect.gd")

## The shortest Speedup, in seconds (the SPEL's duration when it is longer).
@export var min_duration_s := 1.0


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if user.get_node_or_null(_SPEEDUP.NODE_NAME) != null:
		return ActiveAbility.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority():
		return false
	if user.get_node_or_null(_SPEEDUP.NODE_NAME) != null:
		return true
	var speed: Node = _SPEEDUP.new()
	speed.name = _SPEEDUP.NODE_NAME
	speed.call("start", maxf(ability.duration, min_duration_s))
	user.add_child(speed)
	if user.has_method("halt"):
		user.call("halt")
	FxBus.broadcast("speedup", user.global_position + Vector3.UP)
	return true
