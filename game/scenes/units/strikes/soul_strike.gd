class_name SoulStrike
extends ShotStrike

## The blow of the Styx's Rend Soul. It is an effect born in the tick of the shot and updated once
## on the next: it checks the Rend rule again; if the soul is still there it bursts (Soul.burst
## dissolves the corpse), draws the StyxBolt from the shot origin to the soul's center and deals a
## splash of ranged damage over the damage range: that is ShotLook.impact
## (impacts/rend_blast_impact.tscn: nobody takes the whole amount). If the soul went, nothing
## happens (the mana is already spent). Born from RendSoul, not from RangedWeapon.

## The beam from the shot origin to the soul's center. Empty: none.
@export var beam: BeamType = preload("res://scenes/fx/effects/beams/styx.tres")
## Tick it lands on (1 = the tick after the shot).
@export_range(0, 120) var land_tick := 1

## The soul to rend. Set by RendSoul before launch().
var soul: Soul


## The soul's center: its position lifted 0.5·1.25 of its scaling.
static func center_of_soul(of: Soul) -> Vector3:
	return of.global_position + Vector3.UP * (0.5 * 1.25 * of.scaling)


func _strike_tick(age: int) -> void:
	if age < land_tick:
		return
	if not RendSoul.can_rend(soul, from_slot):
		_log("blow %s %s: the soul is gone (tick %d)" % [tag, shooter_name(), MatchClock.now()])
		finish()
		return
	var point := center_of_soul(soul)
	soul.burst()
	if beam != null:
		FxBus.broadcast_beam(beam, origin, point, null)
	_log(
		(
			"blow %s %s → soul at (%.1f, %.1f, %.1f) at %.1f m (tick %d)"
			% [
				tag,
				shooter_name(),
				point.x,
				point.y,
				point.z,
				origin.distance_to(point),
				MatchClock.now()
			]
		)
	)
	_land(null, point)
	finish()
