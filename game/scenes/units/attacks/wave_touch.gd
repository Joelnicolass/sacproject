class_name WaveTouch
extends Node

## What a GrowingWave does to a body it touches besides the damage. A child of the wave scene; the
## wave calls before_hit(body) right before the damage of a body that takes it (the shot's target or
## a splash body, not a body of the shooter's side), after_hit with what before_hit returned right
## after, and settled() at the end of every update. `direct` says which of the two bodies it is: the
## order is not the same for both (the Spitfire sets a target ablaze after the blow and any other
## body before it). Default: nothing.


## Server (or solo): read what the damage may change. The value goes back to after_hit.
func before_hit(_body: Node3D, _direct: bool, _shot: RangedShot, _wave: GrowingWave) -> Variant:
	return null


func after_hit(_body: Node3D, _direct: bool, _before: Variant, _shot: RangedShot) -> void:
	pass


## The update is over (the Silverback's splash bodies try to freeze here).
func settled(_shot: RangedShot) -> void:
	pass
