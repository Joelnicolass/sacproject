class_name ZoneErupt
extends ZonePulse

## What the ground does to the bodies on it the moment it bursts open: splash damage that falls off to nothing at the
## spell's damage range, and every creature and wizard nearer than `throw_range_m` thrown up and away, harder the closer it
## stands to the center. Then the burst everybody sees (rocks, dust, the light of the blast). It does not lift the ground
## (the zone's TerrainStamps do) nor stun the wave's bodies (ZoneStunRing), and it draws nothing by itself.

## The burst played at the center: a scene with the flying rocks (it also carries the sound of the blast).
@export var burst: PackedScene
## Sprite bursts played at the center (FxBus), under data/fx/. The ones with a light light the ground in their color.
@export var puffs: Array[ParticleType] = []
## Where the burst is born over the center.
@export var burst_at: Marker3D
## Bodies nearer than this to the center (on the ground plane) are thrown.
@export_range(1.0, 100.0, 0.5, "suffix:m") var throw_range_m := 42.5
## The speed of a body thrown from the very center; it falls off to nothing at `throw_range_m`.
@export_range(0.0, 60.0, 0.5, "suffix:m/s") var throw_speed := 20.0
## The up part of the direction of the throw, against the sideways part (the body's distance to the center in metres).
@export_range(0.0, 100.0, 0.5) var throw_up := 20.0


func _fire(_step: int) -> void:
	var spell := zone.spell
	var center := zone.points[0]
	_show(center)
	SplashDamage.deal(
		get_tree(), center, float(spell.damage), spell.damage_range_m, null, zone.from_slot
	)
	for body in bodies_near(center, throw_range_m):
		var away := body.global_position - center
		away.y = 0.0
		var tumbling := BodyNudge.tumbling_of(body)
		if tumbling != null and away.length() < throw_range_m:
			var push := (
				Vector3(away.x, throw_up, away.z).normalized()
				* throw_speed
				* (1.0 - away.length() / throw_range_m)
			)
			tumbling.catapult(push, zone.from_slot)


func _show(center: Vector3) -> void:
	var at := center + (burst_at.position if burst_at != null else Vector3.ZERO)
	for type in puffs:
		FxBus.broadcast(type, at)
	if burst != null:
		FxBus.broadcast_scene(burst, at, {})
