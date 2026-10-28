class_name TimedStateAbility
extends AbilityEffect

## An ability that turns one of the SpecialForms of a UnitBody on for a time and off again: Play
## Dead (dedp) and Stealth (ivni). Which form is `form`; the time is «until tick N» on MatchClock,
## the SPEL's duration but never less than `min_duration_s`. Refused while it is on. Server only
## (fire() needs authority).

## Which form of the creature it turns on.
@export var form := SpecialForms.Form.PLAYING_DEAD
## The shortest time the flag stays on, in seconds (the SPEL's duration when it is longer).
@export var min_duration_s := 6.0
## The burst every peer sees when the flag turns on, and the socket of the body it leaves from
## (empty = none).
@export var fx: ParticleType = preload("res://data/fx/dirt.tres")
@export var fx_socket: BodyFacts.Socket = BodyFacts.Socket.FEET

## MatchClock tick at which the flag ends (0 = off).
var _until := 0


func status(_target_pos: Vector3, _target: Node3D) -> String:
	if _until > 0:
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	_until = (
		MatchClock.now()
		+ roundi(maxf(ability.duration_s, min_duration_s) * MatchClock.TICKS_PER_SECOND)
	)
	user.special_forms.set_form(form, true)
	if fx != null:
		FxBus.broadcast(fx, BodyFacts.point(user, fx_socket))
	set_physics_process(true)
	return true


func _physics_process(_delta: float) -> void:
	if _until > 0 and MatchClock.now() >= _until:
		_until = 0
		if user:
			user.special_forms.set_form(form, false)
	if _until == 0:
		set_physics_process(false)
