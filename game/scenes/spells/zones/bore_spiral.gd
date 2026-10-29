class_name BoreSpiral
extends RefCounted

## The path of a Bore: a spiral that opens around the click from 5 m out to the spell's reach,
## `step_m` along the turn each tick (the radius grows with the angle, so the turns get further
## apart as it goes). `advance()` gives the place for this tick and moves on; `arrived` is true once
## the last place was given. The drill that bores and the cutter that opens the holes both walk it,
## each at its own pace. It knows nothing of the ground.

## The inner end of the spiral.
const START_RADIUS_M := 5.0
## Turns per metre of radius.
const ANGLE_PER_M := 0.2 * PI

var center := Vector2.ZERO
var reach_m := 50.0
var step_m := 0.8
var angle := 0.0
var arrived := false


func _init(at: Vector2, reach: float, step: float) -> void:
	center = at
	reach_m = reach
	step_m = step


## The place (x, z) of this tick; then the walker moves along the turn.
func advance() -> Vector2:
	var last := (reach_m - START_RADIUS_M) * ANGLE_PER_M
	if not last > angle:
		angle = last
		arrived = true
	var radius := (
		(reach_m - START_RADIUS_M) * angle / last + START_RADIUS_M if last > 0.0 else START_RADIUS_M
	)
	var place := center + radius * Vector2(sin(angle), cos(angle))
	angle += step_m / radius
	return place


## The place after `ticks` steps from the start (a peer that joins late finds where the walker is).
func skip(ticks: int) -> Vector2:
	var place := Vector2.ZERO
	for _tick in ticks:
		place = advance()
	return place
