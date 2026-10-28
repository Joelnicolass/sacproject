class_name BloodType
extends Resource

## How one kind of body bleeds: the spray a light and a heavy hit throw, how much health it must
## lose before it bleeds again, and the mark the blood leaves on the ground (how many, how far from
## the feet). Every creature and wizard bleeds red (data/fx/blood/red.tres) unless its look picks
## another type.
## What it does not do: decide when a body bleeds (BloodFx, BloodRules) or paint anything
## (GroundScars).

## The burst a light hit throws from the body's center. Empty: no spray.
@export var spray: ParticleType
## The burst a heavy hit throws. Empty: `spray`.
@export var heavy_spray: ParticleType
## A single drop of at least this share of the maximum health is a heavy hit.
@export_range(0.0, 1.0, 0.01) var heavy_from := 0.4
## Hits close together (poison, a wall of fire) add up until this share of the maximum is lost; an
## isolated hit always bleeds.
@export_range(0.0, 1.0, 0.01) var min_lost := 0.04
## The least time between two sprays of the same body; also how long without a hit makes the next
## one isolated.
@export_range(0.0, 5.0, 0.05, "suffix:s") var every_s := 0.25
## The mark on the ground: a SCAR picture (a pixel is 0.15625 m; blud.png is 1.25 m). Empty: no
## marks.
@export var mark: Texture2D
@export_range(0, 8) var marks_per_spray := 1
@export_range(0, 16) var heavy_marks := 3
## How far from the feet the marks land.
@export_range(0.0, 10.0, 0.1, "suffix:m") var mark_radius_m := 1.5
## No mark when the feet are this far over the ground (a flier).
@export_range(0.0, 10.0, 0.1, "suffix:m") var mark_max_height_m := 1.0


## True when this type shows anything at all.
func bleeds() -> bool:
	return spray != null or heavy_spray != null or mark != null


func spray_for(heavy: bool) -> ParticleType:
	return heavy_spray if heavy and heavy_spray != null else spray


func marks_for(heavy: bool) -> int:
	return heavy_marks if heavy else marks_per_spray
