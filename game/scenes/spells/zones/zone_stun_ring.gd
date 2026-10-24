class_name ZoneStunRing
extends ZonePulse

## A wave that runs out from the center of the zone and stuns whoever it crosses between two distances: one pulse each
## tick, the ring at `wave_range_m` over `wave_s` seconds, and every creature and wizard standing within `band` ticks of
## travel of it (and farther than `stun_min_m`) is stunned, once per its own cooldown. No damage, no throw. The crest the
## player sees is the zone's wave stamp; this one only decides who falls. Server (or solo) only.
## Ref: sacengine updateErupt (state.d:18506-18520).

## How far the ring goes and how long it takes.
@export_range(1.0, 300.0, 0.5, "suffix:m") var wave_range_m := 90.0
@export_range(0.05, 10.0, 0.05, "suffix:s") var wave_s := 1.0
## It stuns only while the ring is between these two distances.
@export_range(0.0, 300.0, 0.5, "suffix:m") var stun_min_m := 50.0
@export_range(0.0, 300.0, 0.5, "suffix:m") var stun_max_m := 75.0
## Half the width of the stunned band, in ticks of travel of the ring.
@export_range(0.5, 10.0, 0.1) var band := 1.5
@export var cooldown_ticks := 480
## The path of the Stunned state under each body.
@export var stunned_path := NodePath("Afflictions/Stunned")


## Where the ring is `step` ticks after the burst.
func ring_at(step: int) -> float:
	return wave_range_m * (float(step) / MatchClock.TICKS_PER_SECOND_F) / wave_s


## Half the width of the stunned band (m).
func half_band_m() -> float:
	return band * wave_range_m / (wave_s * MatchClock.TICKS_PER_SECOND_F)


func _fire(step: int) -> void:
	var loc := ring_at(step)
	if loc <= stun_min_m or loc >= stun_max_m:
		return
	var center := zone.points[0]
	for body in bodies_near(center, loc + 0.1):
		var flat := Vector2(body.global_position.x - center.x, body.global_position.z - center.z).length()
		if flat > stun_min_m and absf(flat - loc) < half_band_m():
			var stunned := body.get_node_or_null(stunned_path) as Stunned
			if stunned != null:
				stunned.stun_with_cooldown(cooldown_ticks)
