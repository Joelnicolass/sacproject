extends DeathCloud

## Healing Shower (tum@, Mutant and Dragon). Every body of the dead
## one's own side within effect range of the center gets heal(). The SPEL amount is replaced by
## infinity, and heal() turns that into the body's max health: max health in total
## at 240 per second, ceil(max health/240·60) frames, cut short when the bar is full.
## A body already full is skipped; one already healing adds the frames.
## Sirocco has tum@ too.

const _HEAL := preload("res://scenes/spells/heal_effect.gd")


func _affect(center: Vector3) -> void:
	for body in bodies_within(center, ability.effect_range_m):
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
