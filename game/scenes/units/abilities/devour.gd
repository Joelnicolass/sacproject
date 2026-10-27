class_name DevourAbility
extends AbilityEffect

## The Netherfiend's and the Hellmouth's Devour: eating a soul. The body prepares (72 ticks for the Netherfiend, 92 for the Hellmouth)
## and at the shoot tick the soul is devoured. It costs no mana and has no cooldown, so AbilitySlot spends 0.
## The preparation is AbilityWindup's (UsingAbility + windup()); what the soul goes through is Soul's (begin_devour); what the
## eater becomes is DevourGrowth's; the cure is HealEffect's. This effect only judges the target and tells them.
##
## Target: a soul (or the corpse it waits on) that is blue for the eater's slot (free or
## its own), NORMAL or EMERGING, within the length of the eater's box measured in 2D.
## Declared: the creature does not walk closer or turn (the original does); out of range is refused.
## Ref: F131 (RFC-030 030t-a); Netherfiend crpd, Hellmouth nomd, Devour ifna (flags 4098), sacengine useAbility → shoot1 (state.d:13463-13561; PCes c36, DMes c46), devourSoul 12735-12736, 13138-13163, isApplicable/summarize 30820-30825, useAbilityDistance 12474, moveWithinRange2D 12526-12529.

const _HEAL := preload("res://scenes/spells/heal_effect.gd")

## Multiplies the length of the box (|(2·reach, height, 2·reach)| of the body's melee_profile).
@export var reach_factor := 1.0
## The spell that heals the eater after the meal (data/catalog/spells/wobr.tres, Rainbow: 600 health at 240/s, only if it is not full).
@export var healing: SpellType


func status(_target_pos: Vector3, target: Node3D) -> String:
	if ability == null or user == null:
		return Refusal.BAD_TARGET
	var soul := _soul_of(target)
	if soul == null or not soul.is_free_or_own(_slot()) or not (soul.state == Soul.State.NORMAL or soul.state == Soul.State.EMERGING):
		return Refusal.BAD_TARGET
	if _flat_distance(soul) > reach():
		return Refusal.OUT_OF_RANGE
	return ""


## devourSoul. False = nothing happened (the soul is gone by the shoot tick): the cost is 0 all the same.
func fire(target_pos: Vector3, target: Node3D) -> bool:
	if not is_multiplayer_authority():
		return false
	if not status(target_pos, target).is_empty():
		if DebugLog.on(&"effects"):
			print("devorar %s sin blanco válido (tick %d)" % [who(user), MatchClock.now()])
		return false
	var soul := _soul_of(target)
	var number := soul.number
	var from := soul.label()
	soul.begin_devour(user)
	var growth := DevourGrowth.of(user)
	if growth != null:
		growth.grow(number, from)
	if _HEAL.can_heal(user):
		var heal := _HEAL.on(user) as HealEffect
		heal.add(_heal_amount())
		heal.report_each = DebugLog.on(&"effects")
	return true


## How far the eater reaches: the length of its box.
func reach() -> float:
	var profile := user.melee_profile()
	var half := float(profile.get("reach", 0.35))
	return reach_factor * Vector3(2.0 * half, float(profile.get("height", 1.8)), 2.0 * half).length()


func _heal_amount() -> float:
	return float(healing.damage) if healing else 0.0


## The soul the order was given on: the soul itself or the corpse it waits on.
func _soul_of(target: Node3D) -> Soul:
	if target == null or not is_instance_valid(target):
		return null
	return target as Soul if target is Soul else Soul.on_corpse(target)


func _flat_distance(soul: Soul) -> float:
	var d := soul.global_position - user.global_position
	return Vector2(d.x, d.z).length()


func _slot() -> int:
	return int(user.get("owner_slot")) if "owner_slot" in user else 0
