extends DeathCloud

## Steam Cloud (goc@, Cog and Phoenix). It is a dealSplashSpellDamageAt with the
## SPEL amount over damageRange, from the dead body's center, once (amount·(1 − d/r), splash spell).
## SplashDamage is that same call (it also hits buildings). It carries DamageMod.ignite (F155): it only matters on oiled bodies.
## Ref: sacengine updateSteamCloud state.d:25216-25233, 9053-9056.


func _affect(center: Vector3) -> void:
	var before := {}
	for body in bodies_within(center, ability.damage_range_m):
		before[body] = float(body.get_node("Health").get("current"))
	_SPLASH.deal(get_tree(), center, float(ability.damage), ability.damage_range_m, dead, from_slot, Health.SPLASH_SPELL, Health.IGNITE)
	for body: Node3D in before:
		if is_instance_valid(body):
			print("  vapor %s vida %d -> %d" % [GameBody.name_of(body), roundi(before[body]), roundi(float(body.get_node("Health").get("current")))])
