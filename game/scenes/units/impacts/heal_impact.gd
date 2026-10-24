class_name HealImpact
extends ShotImpact

## F136 (RFC-030h2): the Scarab's Healing web. sacengine scarabProjectileHit (state.d:23609-23627) calls
## dealSplashSpellDamageAt(-1, …, effectRange) with a callback that heals every moving body of the shooter's side
## (the shooter included) whose box is within effectRange of the burst and returns false: nobody is damaged, no
## building either. heal() with the infinite amount of slba (sacspell.d:211): maxHealth at 240/s, satAdd (10443-10458),
## the same rule as the Healing Shower (HealEffect.heal_full).

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")
const _HEAL := preload("res://scenes/spells/heal_effect.gd")

## sacengine movingObjects: creatures and wizards.
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var radius := ability.effect_range_m if ability else 0.0
	print("telarana %s en (%.1f, %.1f, %.1f) radio %.1f m slot %d" % [ability.tag if ability else "?", point.x, point.y, point.z, radius, from_slot])
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		if int(body.get("owner_slot")) != from_slot or _HEAL.heal_full(body, true) == null:
			continue
		var health := body.get_node("Health")
		print("  cura a %s (vida %d/%d)" % [who(body), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
