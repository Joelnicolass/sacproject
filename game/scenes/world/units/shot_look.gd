class_name ShotLook
extends Resource

## How a creature's ranged shot looks: res://data/shots/<ability tag>.tres. Flight and damage
## come from the AbilityType; a tag without a .tres flies as a plain ball with no particles.

## Baked model (BodyLibrary); empty = a ball of fallback_radius.
@export var model := ""
@export var model_scale := 1.0
## Side of the hit box in meters.
@export var hit_size := 0.7
## Random spin in turns per second around a random axis.
@export var spin_min := 0.0
@export var spin_max := 0.0
## FxBus type played along the flight on every peer, by time (FxTrail): one puff per
## trail_every / 60 s, whatever the frame rate.
@export var trail_fx := ""
@export var trail_every := 1
## FxBus types broadcast where it bursts.
@export var impact_fx: PackedStringArray = PackedStringArray()
## F119: ShotImpact scene the server (or solo) applies where it bursts, in place of the plain direct ranged hit
## (impacts/*.tscn). Empty = the whole amount as direct ranged damage to the body it hit.
@export var impact: PackedScene
## F136: the shot bursts on its target or on any body of the shooter's side, and flies through the rest
## (scarabProjectileCollisionTarget, state.d:23637-23642). Off: its target or any body not of the shooter's side.
@export var hits_allies := false
## F136: when its box touches nothing this frame, it also checks the segment it flew (lineOfSight in
## updateScarabProjectile, state.d:23655-23664), so a small fast shot does not pass through a body. slba; F121: amba and cita too (lineOfSightWithoutSide, 23863, 23992).
@export var sweep := false
## F136: at the end of its range it bursts there (impact included) instead of vanishing (updateScarabProjectile,
## state.d:23667-23670). slba; F121: cita too (its vortex spawns where the range ends, state.d:23866).
@export var burst_at_range_end := false
## F148/F149: ShotInFlight scene the server (or solo) puts on the shot; it acts on every tick of the flight. tugt: a
## ShotDropper (a droplet that falls on whoever is below, animateAbominationProjectile, state.d:24441-24452); rdba: a
## FrostWave (the Silverback's breath grows and freezes, updateSilverbackProjectile, 24758-24831).
@export var in_flight: PackedScene
## F149: off, the shot touches nothing on its way, neither a body nor the ground, and flies its whole range (the
## Silverback's breath: its in_flight does the damage). On: it bursts on its hit (the rest of the shots).
@export var collides := true
@export var fallback_color := Color(0.8, 0.7, 0.5)
@export var fallback_radius := 0.15
