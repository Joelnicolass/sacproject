extends DeathCloud

## Healing Shower (tum@, Mutant and Dragon). Every body of the dead
## one's own side within effectRange of the center gets heal(). The SPEL amount is replaced by
## infinity, and heal() turns that into the body's maxHealth: maxHealth in total
## at healSpeed 240 per second, ceil(maxHealth/240·60) frames, cut short when the bar is full (updateHeal).
## A body already full is skipped (canHeal); one already healing adds the frames (satAdd).
## Sirocco (risH) has tum@ too.
## Ref: sacengine updateHealingShower state.d:25674-25697, heal() 10444-10458, 10446-10449, satAdd 10455, sacspell.d:211, updateHeal 16293-16310.

const _HEAL := preload("res://scenes/spells/heal_effect.gd")


func _affect(center: Vector3) -> void:
	for body in bodies_within(center, ability.effect_range_m):
		if int(body.get("owner_slot")) != from_slot or _HEAL.heal_full(body, true) == null:
			continue
		var health := body.get_node("Health")
		print("  cura a %s (vida %d/%d)" % [GameBody.name_of(body), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
