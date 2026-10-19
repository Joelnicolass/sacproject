class_name IgniteTouch
extends WaveTouch

## F162 (030w-c): the fire of the Spitfire's wave (fhba, updateSpitfireProjectile, state.d:23025-23069). Every body it
## touches burns for 30 updates (updateFPS / 2) with no damage: setAblaze(id, lifetime, true, 0.0f, …). The fire is
## not what hurts; the damage of the blow carries DamageMod.ignite (ShotLook.ignites -> shot.mods), which doubles on an
## oiled body (F155). Order of sacengine: the shot's target takes the blow and then the fire; any other body (not of the
## shooter's side) the fire and then the splash.

## Updates the fire lasts (sacengine updateFPS / 2).
@export var fire_ticks := 30
## Damage of the whole fire (the original sets it to 0).
@export var fire_damage := 0.0
## FxBus fire puffed on a creature while it burns (presentation only, like BurnImpact and Oiled).
@export var fire_fx := "fire"


func before_hit(body: Node3D, direct: bool, shot: RangedShot, _wave: GrowingWave) -> Variant:
	if not direct:
		_ignite(body, shot)
	return null


func after_hit(body: Node3D, direct: bool, _before: Variant, shot: RangedShot) -> void:
	if direct:
		_ignite(body, shot)


func _ignite(body: Node3D, shot: RangedShot) -> void:
	Burning.ignite(body, fire_damage, fire_ticks, Health.DIRECT_RANGED, shot.from_slot, 0.0, false, fire_fx, ShotImpact.shooter_of(shot))
