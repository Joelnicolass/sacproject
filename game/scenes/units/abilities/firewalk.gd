class_name Firewalk
extends AbilityEffect

## F152 (RFC-030 030o-b): the Warmonger's Firewalk (wfhg, flags targetGround). sacengine useAbility → shoot!false
## (state.d:13470-13493): the body prepares (startUsingAbility, shoot1) and at the shoot tick shootOnTick calls
## firewalk (13213-13217) and drains the mana even if it fails (12746-12748); the cooldown is set if it was 0.
## firewalk refuses a target that is not on the ground (isOnGround) and else adds the Firewalk effect.
## The range is the SPEL's cast_range · 0.75 (sacspell.d:208: 200 → 150). AbilityType.cast_range_m stays 200 (the rater
## reads it), so the factor is this knob. Out of range is refused (declared: sacengine walks closer first).
## The preparation is ActiveAbility's (UsingAbility + windup()); the walk is Firewalking's.

## sacengine SacSpell: `if(tag==SpellTag.firewalk) range*=0.75f`.
@export var range_factor := 0.75


func status(target_pos: Vector3, _target: Node3D) -> String:
	if ability == null or Firewalking.of(user) == null or not BodyNudge.on_land(user, target_pos):
		return ActiveAbility.BAD_TARGET
	if user.global_position.distance_to(target_pos) > ability.cast_range_m * range_factor:
		return ActiveAbility.OUT_OF_RANGE
	return ""


## True even when the land refuses (no walk): sacengine spends the mana at the shoot tick all the same.
func fire(target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority():
		return false
	var walker := Firewalking.of(user)
	var done := walker != null and BodyNudge.on_land(user, target_pos) and walker.walk(target_pos)
	if DebugLog.on(&"effects"):
		print("firewalk %s: %s (tick %d)" % [who(user), "camina" if done else "rechazado", MatchClock.now()])
	return true
