class_name ZoneBurst
extends ZonePulse

## What a zone lets out at one moment (or every so often): the sprite bursts, the scene and the marks on the ground everybody sees,
## and, if `damage_radius_m` says so, a splash of the spell's damage that falls off to nothing at that distance around the zone's
## first point. It does not throw or set anyone alight (ZoneBlast, ZoneHeat) nor time itself (ZonePulse). Server (or solo) only; the
## bursts reach every peer through FxBus.
## Ref: sacengine updateVolcano (state.d:22353-22362, 22369).

## The burst scene played over the first point (it also carries the sound).
@export var burst: PackedScene
## Sprite bursts played there (FxBus), under data/fx/. The ones with a light light the ground in their color.
@export var puffs: Array[ParticleType] = []
## Marks painted on the ground there (ScarMark scenes), on every peer.
@export var marks: Array[PackedScene] = []
## Where the burst is born over the point.
@export var burst_at: Marker3D
## Splash damage from the spell's damage, falling off to nothing at this distance (0 = it does not hurt).
@export_range(0.0, 200.0, 0.5, "suffix:m") var damage_radius_m := 0.0


func _fire(_step: int) -> void:
	var point := zone.points[0]
	var at := point + (burst_at.position if burst_at != null else Vector3.ZERO)
	for type in puffs:
		FxBus.broadcast(type, at)
	if burst != null:
		FxBus.broadcast_scene(burst, at, {})
	for mark in marks:
		ScarMark.broadcast(mark, point)
	if damage_radius_m > 0.0:
		SplashDamage.deal(get_tree(), point, float(zone.spell.damage), damage_radius_m, null, zone.from_slot)
