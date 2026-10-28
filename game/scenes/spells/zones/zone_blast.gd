class_name ZoneBlast
extends ZonePulse

## What an explosion zone does when it goes off, at each of its points: splash damage that falls off
## with distance, a fire of no damage on every body it reaches, the burst everybody sees, and then
## the throw of every body near the first point. It does not time the blast (the zone and ZonePulse
## do) nor draw the balls (the zone's look).

## The burst played at each point: a scene with the spheres and the debris (it also carries the
## sound of the blast).
@export var burst: PackedScene
## Sprite bursts played at each point (FxBus), under data/fx/.
@export var puffs: Array[ParticleType] = []
## The fire a body keeps for `burn_s` (no damage: it is the look), and the sprite it puffs.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var burn_s := 1.0
@export var burn_look: ParticleType
## Bodies within the spell's effect range plus its damage range of the first point are thrown.
@export var throws := true
## Where the burst is born over each point.
@export var burst_at: Marker3D


func _fire(_step: int) -> void:
	var spell := zone.spell
	for point in zone.points:
		_show(point)
		SplashDamage.deal(
			get_tree(),
			point,
			float(spell.damage),
			spell.damage_range_m,
			null,
			zone.from_slot,
			Health.SPLASH_SPELL,
			Health.IGNITE
		)
		for body in SplashDamage.bodies_within(get_tree(), point, spell.damage_range_m):
			Burning.ignite(
				body,
				0.0,
				MatchClock.ticks_for(burn_s),
				Health.DIRECT_SPELL,
				zone.from_slot,
				0.0,
				false,
				burn_look
			)
	if throws:
		_throw_all()


## Every body near the first point leaves from the closest blast it answers to (the first one when
## it is in range).
func _throw_all() -> void:
	var spell := zone.spell
	for body in bodies_near(zone.points[0], spell.effect_range_m + spell.damage_range_m):
		var i := ZoneRules.nearest_blast(zone.points, body.global_position, spell.damage_range_m)
		var tumbling := BodyNudge.tumbling_of(body)
		if i >= 0 and tumbling != null:
			tumbling.catapult(
				ZoneRules.throw_velocity(
					body.global_position, zone.points[i], spell.damage_range_m
				),
				zone.from_slot
			)


func _show(point: Vector3) -> void:
	var at := point + (burst_at.position if burst_at else Vector3.ZERO)
	for type in puffs:
		FxBus.broadcast(type, at)
	if burst != null:
		FxBus.broadcast_scene(burst, at, {})
