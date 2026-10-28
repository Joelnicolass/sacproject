class_name IgniteTouch
extends WaveTouch

## The fire of the Spitfire's wave. Every body it
## touches burns for 30 updates (half a second) with no damage. The fire is
## not what hurts; the damage of the blow carries DamageMod.ignite (ShotLook.ignites -> shot.mods), which doubles on an
## oiled body. Order: the shot's target takes the blow and then the fire; any other body (not of the
## shooter's side) the fire and then the splash.

## How long the fire lasts.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var fire_s := 0.5
## Damage of the whole fire.
@export var fire_damage := 0.0
## The fire puffed on a creature while it burns (presentation only, like BurnImpact and Oiled). Empty = none.
@export var fire_fx: ParticleType = preload("res://data/fx/fire.tres")


func before_hit(body: Node3D, direct: bool, shot: RangedShot, _wave: GrowingWave) -> Variant:
	if not direct:
		_ignite(body, shot)
	return null


func after_hit(body: Node3D, direct: bool, _before: Variant, shot: RangedShot) -> void:
	if direct:
		_ignite(body, shot)


func _ignite(body: Node3D, shot: RangedShot) -> void:
	Burning.ignite(body, fire_damage, MatchClock.ticks_for(fire_s), Health.DIRECT_RANGED, shot.from_slot, 0.0, false, fire_fx, ShotImpact.shooter_of(shot))
