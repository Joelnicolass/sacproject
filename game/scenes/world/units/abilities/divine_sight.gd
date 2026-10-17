class_name DivineSight
extends AbilityEffect

## F133 (RFC-030 030v-a): the Ranger's Divine Sight (eesd), moved from ActiveAbility's branches without a change. It asks for a target and
## the SPEL's range, then reveals it (stealth off, special states cleared). Declared: the SPEL has flags 0, so a click from the UI carries no
## target and always gives «Blanco inválido»; the original throws an eye forward (state.d:13102-13108). The faithful fix is F165.


func status(target_pos: Vector3, target: Node3D) -> String:
	if target == null:
		return ActiveAbility.BAD_TARGET
	if user.global_position.distance_to(target_pos) > ability.cast_range:
		return ActiveAbility.OUT_OF_RANGE
	return ""


func fire(_target_pos: Vector3, target: Node3D) -> bool:
	if not _has_authority():
		return false
	if target and target.has_method("set_stealth"):
		target.call("set_stealth", false)
	if target and target.has_method("clear_special_states"):
		target.call("clear_special_states")
	FxBus.broadcast("spit_rock", user.global_position + Vector3.UP)
	if target:
		FxBus.broadcast("spit_dirt", target.global_position + Vector3.UP * 0.5)
	return true
