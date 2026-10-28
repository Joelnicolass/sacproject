class_name RunAway
extends AbilityEffect

## Run Away (the Flame Minion's, the Silverback's, the Frostwolf's), moved from AbilitySlot's branches without a
## change. The body takes a Speedup (SpeedupEffect, duration ≥ 1 s), stops and drops its orders. Refused while it already has one.

const _SPEEDUP_SCENE := preload("res://scenes/spells/speedup_effect.tscn")

## The shortest Speedup, in seconds (the SPEL's duration when it is longer).
@export var min_duration_s := 1.0
## The burst every peer sees when it runs, and the socket of the body it leaves from (empty = none).
@export var fx: ParticleType = preload("res://data/fx/speedup.tres")
@export var fx_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if user.get_node_or_null(SpeedupEffect.NODE_NAME) != null:
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	if user.get_node_or_null(SpeedupEffect.NODE_NAME) != null:
		return true
	var speed := _SPEEDUP_SCENE.instantiate() as SpeedupEffect
	speed.name = SpeedupEffect.NODE_NAME
	speed.start(maxf(ability.duration_s, min_duration_s))
	user.add_child(speed)
	user.halt()
	if fx != null:
		FxBus.broadcast(fx, BodyFacts.point(user, fx_socket))
	return true
