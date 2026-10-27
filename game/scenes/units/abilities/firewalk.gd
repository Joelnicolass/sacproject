class_name Firewalk
extends AbilityEffect

## The Warmonger's Firewalk: it walks through the land as fire to a ground spot. The body prepares and at the shoot tick
## the walk starts and the mana is drained even if it fails; the cooldown is set if it was 0.
## It refuses a target that is not on the ground and else adds the Firewalk effect.
## The range is the spell's cast_range · 0.75 (200 → 150). AbilityType.cast_range_m stays 200 (the rater
## reads it), so the factor is this knob. Out of range is refused (declared: the original walks closer first).
## The preparation is AbilityWindup's (UsingAbility + windup()); the walk is Firewalking's.
## Ref: F152 (RFC-030 030o-b); Warmonger wfhg (flags targetGround), sacengine useAbility → shoot!false (state.d:13470-13493), firewalk 13213-13217, 12746-12748, isOnGround, sacspell.d:208.

## The range factor of the spell.
## Ref: sacengine SacSpell `if(tag==SpellTag.firewalk) range*=0.75f`.
@export var range_factor := 0.75


func status(target_pos: Vector3, _target: Node3D) -> String:
	if ability == null or Firewalking.of(user) == null or not BodyNudge.on_land(user, target_pos):
		return Refusal.BAD_TARGET
	if user.global_position.distance_to(target_pos) > ability.cast_range_m * range_factor:
		return Refusal.OUT_OF_RANGE
	return ""


## True even when the land refuses (no walk): the original spends the mana at the shoot tick all the same.
func fire(target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	var walker := Firewalking.of(user)
	var done := walker != null and BodyNudge.on_land(user, target_pos) and walker.walk(target_pos)
	if DebugLog.on(&"effects"):
		print("firewalk %s: %s (tick %d)" % [who(user), "camina" if done else "rechazado", MatchClock.now()])
	return true
