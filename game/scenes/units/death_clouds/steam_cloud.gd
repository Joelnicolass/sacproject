extends DeathCloud

## Steam Cloud (goc@, Cog and Phoenix). It is a splash of spell damage with the
## SPEL amount over its damage range, from the dead body's center, once (amount·(1 − d/r), splash spell).
## SplashDamage is that same call (it also hits buildings). It carries DamageMod.ignite: it only matters on oiled bodies.


func _affect(center: Vector3) -> void:
	var before := {}
	for body in bodies_within(center, ability.damage_range_m):
		before[body] = float(body.get_node("Health").get("current"))
	_SPLASH.deal(
		get_tree(),
		center,
		float(ability.damage),
		ability.damage_range_m,
		dead,
		from_slot,
		Health.SPLASH_SPELL,
		Health.IGNITE
	)
	for body: Node3D in before:
		if is_instance_valid(body):
			print(
				(
					"  steam %s health %d -> %d"
					% [
						GameBody.name_of(body),
						roundi(before[body]),
						roundi(float(body.get_node("Health").get("current")))
					]
				)
			)
