class_name ShotInFlight
extends Node

## F149 (RFC-030 030k-b): what a creature's ranged shot does on every tick of its flight, besides moving. The scene is
## ShotLook.in_flight; RangedShot instances it on the server (or solo) only, as a child of the shot, and calls fly()
## once per physics tick, after it moved and before it checks its hit (sacengine updates the projectile's effect in
## the same frame as its move: animateAbominationProjectile, state.d:24454-24460; updateSilverbackProjectile, 24760-24831).
## Variants: ShotDropper (the Abomination's droplets, F148) and FrostWave (the Silverback's breath, F149). They
## override _fly(); the count of ticks is this node's.

## Ticks the shot flew with this node (1 on the first call of fly()).
var ticks := 0


## Server (or solo): one tick of flight. `shot` is the RangedShot (damage and from_slot already scaled by the
## shooter); `at` is where it is now.
func fly(shot: RangedShot, at: Vector3) -> void:
	ticks += 1
	_fly(shot, at)


## What this node does on a tick of flight. Default: nothing.
func _fly(_shot: RangedShot, _at: Vector3) -> void:
	pass


## True when this node owns the shot's height (F151: GroundHug, sacengine position.z = getHeight): RangedShot then skips its
## ground check, and the shot ends on a body or at the end of its range only. Default: false.
func holds_height() -> bool:
	return false


## True once the shot has nothing left to do (F156: a stopped Bilemite after its 30 ticks of fade): RangedShot frees it. Default: false.
func spent() -> bool:
	return false
