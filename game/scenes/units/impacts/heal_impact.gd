class_name HealImpact
extends ShotImpact

## The Scarab's Healing web. It heals every moving body of the shooter's side
## (the shooter included) whose box is within effectRange of the burst: nobody is damaged, no
## building either. The heal has an infinite amount: maxHealth at 240/s,
## the same rule as the Healing Shower (HealEffect.heal_full).
## Ref: F136 (RFC-030h2); sacengine scarabProjectileHit (state.d:23609-23627, dealSplashSpellDamageAt(-1, …, effectRange)), slba sacspell.d:211, satAdd 10443-10458.

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")
const _HEAL := preload("res://scenes/spells/heal_effect.gd")

## Moving bodies: creatures and wizards.
## Ref: sacengine movingObjects.
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var radius := ability.effect_range_m if ability else 0.0
	print("telarana %s en (%.1f, %.1f, %.1f) radio %.1f m slot %d" % [ability.tag if ability else "?", point.x, point.y, point.z, radius, from_slot])
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		if int(body.get("owner_slot")) != from_slot or _HEAL.heal_full(body, true) == null:
			continue
		var health := body.get_node("Health")
		print("  cura a %s (vida %d/%d)" % [GameBody.name_of(body), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
