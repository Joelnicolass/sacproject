class_name LifeShieldAbility
extends AbilityEffect

## F133 (RFC-030 030v-a): the Druid's and the Shrike's Life Shield (hsba), moved from AbilitySlot's branches without a change.
## sacengine lifeShield (state.d:13092-13100): refused (nothing spent) while the body already has a shield; else the body's
## LifeShield starts for the SPEL's duration (1200 ticks). Not the Ent's Protector (HSba), which also shields its allies.


func status(_target_pos: Vector3, _target: Node3D) -> String:
	var shield := LifeShield.of(user)
	if shield == null or shield.is_on():
		return Refusal.BAD_TARGET
	return ""


func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority():
		return false
	var shield := LifeShield.of(user)
	if shield == null:
		return false
	shield.start_for_ability(ability)
	FxBus.broadcast("heal", user.global_position + Vector3.UP)
	return true
