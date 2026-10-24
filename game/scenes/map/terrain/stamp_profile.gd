class_name StampProfile
extends Resource

## The shape of a stamp pressed on the ground, as curves you can edit in the inspector: how the height falls with the
## distance (`radial`), how it grows and shrinks in time (`timeline`), and, for a wave, where the ring is and how wide
## (`ring_travel`, `ring_width`). A stamp can instead be a picture (`heightmap`) with part of the land flattened to the height
## of its center (`flatten`): a volcano. A template shared by the stamps that point to it; never changed while playing. The size
## and the peak are not here: they are the stamp's `Reach` cylinder (TerrainStamp).

## Across the stamp: x is the distance over the reach (0 at the center, 1 at the edge), y the share of the peak height.
## For a ring, x is the distance from the ring over its half-width. Not needed when the stamp is a `heightmap`.
@export var radial: Curve
## In time: x is seconds since the stamp starts, y the share of the peak height. The stamp is over at the last x.
@export var timeline: Curve
## Optional. Metres from the center where the ring is, by second since the stamp starts. Empty = a mound around the center.
@export var ring_travel: Curve
## Metres from the ring's middle to its edge, by second. Used with `ring_travel`.
@export var ring_width: Curve
@export_group("Picture")
## Optional. A grey picture of the shape (lossless import): one pixel per `heightmap_m` metres around the center, white = the peak
## of the `Reach` cylinder, black = nothing. The center is the middle pixel. The stamp is then fixed to the 10 m lattice.
@export var heightmap: Texture2D
@export_range(1.0, 100.0, 0.5, "suffix:m") var heightmap_m := 10.0
## Optional. How much the land flattens to the height it has at the center before the stamp starts: x is the distance over the
## reach counted as a square (the larger of the two offsets), y the share (1 = all the way to the center's height).
@export var flatten: Curve


## Seconds the stamp lasts.
func duration_s() -> float:
	return timeline.max_domain if timeline != null else 0.0


func is_ring() -> bool:
	return ring_travel != null and ring_width != null


## True when the stamp is a picture and/or flattens: its shift is worked out once from the land under it, not from `radial`.
func has_pattern() -> bool:
	return heightmap != null or flatten != null


func is_ready() -> bool:
	return (radial != null or has_pattern()) and timeline != null and (ring_travel == null) == (ring_width == null)
