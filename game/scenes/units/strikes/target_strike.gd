class_name TargetStrike
extends ShotStrike

## F124 (RFC-030 030m): a blow that lands on its tick with no flight. The Styx (styx_strike.tscn): StyxShoot is an
## effect born in the tick of the shot and updated once on the next (updateStyxShoot, state.d:24154-24172): it lands on
## the center of the intended target while it is a valid target, else on the aimed point, and draws its StyxBolt from
## the shot origin to there. No accuracy. What it does there is ShotImpact.land: dhga's ShotLook.impact is the splash
## of the Mutant (splash_impact.tscn: the whole amount to the target as splash ranged, damageRange falloff to the rest).

## Tick it lands on (1 = the tick after the shot).
@export_range(0, 120) var land_tick := 1
## FxBus beam type (res://data/fx/beams/) from the shot origin to where it lands; its end follows the target while it
## lives (updateStyxBolt, state.d:24183-24195). Empty: none.
@export var beam := ""


func _strike_tick(age: int) -> void:
	if age < land_tick:
		return
	var target := intended()
	var point := center_of(target) if target != null else aim
	if not beam.is_empty():
		FxBus.broadcast_beam(beam, origin, point, target)
	_log("golpe %s %s → %s en (%.1f, %.1f, %.1f) a %.1f m (tick %d)" % [tag, shooter_name(), str(target.name) if target != null else "punto apuntado",
			point.x, point.y, point.z, origin.distance_to(point), MatchClock.now()])
	_land(target, point)
	finish()
