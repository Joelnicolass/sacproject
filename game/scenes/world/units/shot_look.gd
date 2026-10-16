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
@export var fallback_color := Color(0.8, 0.7, 0.5)
@export var fallback_radius := 0.15
