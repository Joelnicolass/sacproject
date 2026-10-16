extends DeathCloud

## Steam Cloud (goc@, Cog and Phoenix). sacengine updateSteamCloud (state.d:25216-25233): dealSplashSpellDamageAt with the
## SPEL amount over damageRange, from the dead body's center, once (amount·(1 − d/r), splash spell, state.d:9053-9056).
## SplashDamage is that same call (it also hits buildings). DamageMod.ignite only matters on oiled bodies (030r).


func _affect(center: Vector3) -> void:
	var before := {}
	for body in bodies_within(center, ability.damage_range):
		before[body] = float(body.get_node("Health").get("current"))
	_SPLASH.deal(get_tree(), center, float(ability.damage), ability.damage_range, dead, from_slot)
	for body: Node3D in before:
		if is_instance_valid(body):
			print("  vapor %s vida %d -> %d" % [who(body), roundi(before[body]), roundi(float(body.get_node("Health").get("current")))])
