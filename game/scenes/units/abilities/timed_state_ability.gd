class_name TimedStateAbility
extends AbilityEffect

## F133 (RFC-030 030v-b): an ability that turns a UnitBody flag on for a time and off again: Play Dead (dedp) and Stealth (ivni), moved
## from AbilitySlot's branches without a change. Which flag is `body_setter`; the time is «until tick N» on MatchClock (RFC-032),
## the SPEL's duration but never less than `min_duration_s`. Refused while its own flag is on. Server only (fire() needs authority).

## UnitBody method that takes a bool: set_playing_dead / set_stealth.
@export var body_setter: StringName = &"set_playing_dead"
## The shortest time the flag stays on, in seconds (the SPEL's duration when it is longer).
@export var min_duration_s := 6.0
## FxBus effect and its height over the body when the flag turns on.
@export var fx: StringName = &"dirt"
@export var fx_height := 0.3

## MatchClock tick at which the flag ends (0 = off).
var _until := 0


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if _until > 0:
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority():
		return false
	_until = MatchClock.now() + roundi(maxf(ability.duration_s, min_duration_s) * MatchClock.TICKS_PER_SECOND)
	if user.has_method(body_setter):  # dynamic: the setter is data (body_setter, set in the scene)
		user.call(body_setter, true)
	FxBus.broadcast(fx, user.global_position + Vector3.UP * fx_height)
	set_physics_process(true)
	return true


func _physics_process(_delta: float) -> void:
	if _until > 0 and MatchClock.now() >= _until:
		_until = 0
		if user and user.has_method(body_setter):  # dynamic: the setter is data (body_setter, set in the scene)
			user.call(body_setter, false)
	if _until == 0:
		set_physics_process(false)
