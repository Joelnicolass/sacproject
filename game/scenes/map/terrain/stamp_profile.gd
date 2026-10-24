class_name StampProfile
extends Resource

## The shape of a stamp pressed on the ground, as curves you can edit in the inspector: how the height falls with the
## distance (`radial`), how it grows and shrinks in time (`timeline`), and, for a wave, where the ring is and how wide
## (`ring_travel`, `ring_width`). A template shared by the stamps that point to it; never changed while playing. The size
## and the peak are not here: they are the stamp's `Reach` cylinder (TerrainStamp).

## Across the stamp: x is the distance over the reach (0 at the center, 1 at the edge), y the share of the peak height.
## For a ring, x is the distance from the ring over its half-width.
@export var radial: Curve
## In time: x is seconds since the stamp starts, y the share of the peak height. The stamp is over at the last x.
@export var timeline: Curve
## Optional. Metres from the center where the ring is, by second since the stamp starts. Empty = a mound around the center.
@export var ring_travel: Curve
## Metres from the ring's middle to its edge, by second. Used with `ring_travel`.
@export var ring_width: Curve


## Seconds the stamp lasts.
func duration_s() -> float:
	return timeline.max_domain if timeline != null else 0.0


func is_ring() -> bool:
	return ring_travel != null and ring_width != null


func is_ready() -> bool:
	return radial != null and timeline != null and (ring_travel == null) == (ring_width == null)
