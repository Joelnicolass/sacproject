class_name RtsCameraEffect
extends Node

## Something a camera adds on top of where it stands (a shake, a sway): RtsCamera3D composes
## `offset()` (local to its view) and `roll()` last, so an effect never feeds back into the follow or
## the pan. Extend it and override both; the kit ships none.


## How far the eye moves, in the camera's own axes (x right, y up, z back).
func offset() -> Vector3:
	return Vector3.ZERO


## Radians the view rolls around its forward axis.
func roll() -> float:
	return 0.0
