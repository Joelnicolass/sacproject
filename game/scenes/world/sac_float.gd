class_name SacFloat
extends RefCounted

## sacengine computes in float32 (D's `float`); GDScript in float64. Where one tick of difference matters (a duration
## ceil'd to ticks, a ring's radius against a threshold) the port rounds every step of the sacengine expression to float32
## with `f32`, as sacengine does, with no epsilon (REVIEW-030k-b N6: 60 · (1000 / 960 · 20) is 1250 there and
## 1250.0000000000002 in a double). Frozen owned this helper (Frozen._f32); F159 (Vined) is the second caller, so it lives here.


## `value` rounded to the nearest float32.
static func f32(value: float) -> float:
	var box := PackedFloat32Array([value])
	return box[0]
