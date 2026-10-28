class_name LightningBolt
extends RefCounted

## Shape of one bolt: `segments + 1` points in the
## bolt's own frame, where +Z runs from the start (z = 0) to the end (z = 1) and X/Y are meters to the side.
## Every inner point is pushed inside a box of side `jitter` (the ends stay on the axis). The caller hands a
## generator of its own, so a beam never moves the match.
##
## z is stored as 10·k/n plus the push and scaled by 0.1·length when drawing:
## the push along the axis is jitter/10 of the whole length, the push to the side is in meters.

const AXIS_UNITS := 10.0

var points := PackedVector3Array()


func _init(segments: int = 10) -> void:
	points.resize(segments + 1)
	for k in points.size():
		points[k] = Vector3(0.0, 0.0, float(k) / float(segments))


## A new shape (size 2.5 by default).
func change_shape(rng: RandomNumberGenerator, jitter: float, factor: float = 1.0) -> void:
	var n := points.size() - 1
	var half := 0.5 * jitter * factor
	for k in points.size():
		var p := Vector3(0.0, 0.0, float(k) / float(n))
		if 0 < k and k < n:
			p.x += rng.randf_range(-half, half)
			p.y += rng.randf_range(-half, half)
			p.z += rng.randf_range(-half, half) / AXIS_UNITS
		points[k] = p


## Point at `t` in 0..1 along the bolt, linear between its points.
func sample(t: float) -> Vector3:
	var n := points.size() - 1
	var f := clampf(t, 0.0, 1.0) * float(n)
	var i := mini(int(floor(f)), n - 1)
	return points[i].lerp(points[i + 1], f - float(i))
