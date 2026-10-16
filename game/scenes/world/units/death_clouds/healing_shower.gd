extends DeathCloud

## Healing Shower (tum@, Mutant and Dragon). sacengine updateHealingShower (state.d:25674-25697): every body of the dead
## one's own side within effectRange of the center gets heal() (state.d:10444-10458). The SPEL amount is replaced by
## infinity (sacspell.d:211), and heal() turns that into the body's maxHealth (state.d:10446-10449): maxHealth in total
## at healSpeed 240 per second, ceil(maxHealth/240·60) frames, cut short when the bar is full (updateHeal, 16293-16310).
## A body already full is skipped (canHeal); one already healing adds the frames (satAdd, state.d:10455).
## Sirocco (risH) has tum@ too.

const _HEAL := preload("res://scenes/world/spells/heal_effect.gd")


func _affect(center: Vector3) -> void:
	for body in bodies_within(center, ability.effect_range):
		if int(body.get("owner_slot")) != from_slot or not _HEAL.can_heal(body):
			continue
		var effect := _HEAL.on(body)
		effect.call("add", float(body.get_node("Health").get("maximum")))
		effect.set("report_end", true)
		var health := body.get_node("Health")
		print("  cura a %s (vida %d/%d)" % [who(body), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
