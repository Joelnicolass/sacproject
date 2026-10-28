class_name LifeShieldAbility
extends AbilityEffect

## The Druid's and the Shrike's Life Shield, moved from AbilitySlot's branches without a change.
## It is refused (nothing spent) while the body already has a shield; else the body's
## LifeShield starts for the spell's duration (1200 ticks). Not the Ent's Protector, which also shields its allies.

## The burst every peer sees when the shield starts, and the socket of the body it leaves from (empty = none).
@export var fx: ParticleType = preload("res://data/fx/heal.tres")
@export var fx_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER


func status(_target_pos: Vector3, _target: Node3D) -> String:
	var shield := LifeShield.of(user)
	if shield == null or shield.is_on():
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	var shield := LifeShield.of(user)
	if shield == null:
		return false
	shield.start_for_ability(ability)
	if fx != null:
		FxBus.broadcast(fx, BodyFacts.point(user, fx_socket))
	return true
