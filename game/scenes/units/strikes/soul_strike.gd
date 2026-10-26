class_name SoulStrike
extends ShotStrike

## F157 (RFC-030 030t-b): the blow of the Styx's Rend Soul. sacengine RendShoot is an effect born in the tick of the shot and updated
## once on the next (updateRendShoot, state.d:25867-25890): it checks canRend again; if the soul is still there it bursts
## (Soul.burst: severSoul dissolves the corpse), draws the StyxBolt from the shot origin to the soul's center and deals
## dealSplashRangedDamageAt(0, …, damageRange): that is ShotLook.impact (impacts/rend_blast_impact.tscn: nobody takes the whole
## amount). If the soul went, nothing happens (the mana is already spent). Born from RendSoulAbility, not from RangedWeapon.

## The beam from the shot origin to the soul's center. Empty: none.
@export var beam: BeamType = preload("res://data/fx/beams/styx.tres")
## Tick it lands on (1 = the tick after the shot).
@export_range(0, 120) var land_tick := 1

## The soul to rend. Set by RendSoulAbility before launch().
var soul: Soul


## sacengine Soul.center: its position lifted 0.5·1.25 of its scaling.
static func center_of_soul(of: Soul) -> Vector3:
	return of.global_position + Vector3.UP * (0.5 * 1.25 * of.scaling)


func _strike_tick(age: int) -> void:
	if age < land_tick:
		return
	if not RendSoulAbility.can_rend(soul, from_slot):
		_log("golpe %s %s: el alma ya no está (tick %d)" % [tag, shooter_name(), MatchClock.now()])
		finish()
		return
	var point := center_of_soul(soul)
	soul.burst()
	if beam != null:
		FxBus.broadcast_beam(beam, origin, point, null)
	_log("golpe %s %s → alma en (%.1f, %.1f, %.1f) a %.1f m (tick %d)" % [tag, shooter_name(), point.x, point.y, point.z,
			origin.distance_to(point), MatchClock.now()])
	_land(null, point)
	finish()
