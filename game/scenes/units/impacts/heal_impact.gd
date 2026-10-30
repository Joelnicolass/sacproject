class_name HealImpact
extends ShotImpact

## The Scarab's Healing web. It heals every moving body of the shooter's side
## (the shooter included) whose box is within effect range of the burst: nobody is damaged, no
## building either. The heal has an infinite amount: max health at 240/s,
## the same rule as the Healing Shower (HealEffect.heal_full).

const _SPLASH := preload("res://scenes/spells/splash_damage.gd")
const _HEAL := preload("res://scenes/spells/heal_effect.gd")

## Moving bodies: creatures and wizards.
@export var groups: Array[StringName] = [&"wizard", &"unit"]


func _affect(shot: Node3D, _target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var from_slot := int(shot.get("from_slot"))
	var radius := ability.effect_range_m if ability else 0.0
	print(
		(
			"web %s at (%.1f, %.1f, %.1f) radius %.1f m slot %d"
			% [ability.tag if ability else "?", point.x, point.y, point.z, radius, from_slot]
		)
	)
	for body in _SPLASH.bodies_within(get_tree(), point, radius, null, groups):
		if int(body.get("owner_slot")) != from_slot or _HEAL.heal_full(body, true) == null:
			continue
		var health := body.get_node("Health")
		print(
			(
				"  heals %s (health %d/%d)"
				% [
					GameBody.name_of(body),
					roundi(float(health.get("current"))),
					roundi(float(health.get("maximum")))
				]
			)
		)
