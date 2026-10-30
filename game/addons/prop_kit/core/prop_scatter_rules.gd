@tool
class_name PropScatterRules
extends Resource

## How a scatter spreads its props: clusters from a noise (woods and clearings, or an even cover
## with `cover` 1), the room between props, their size from a cluster's edge to its heart, and a
## cap. Distances are in world units: metres in 3D, pixels in 2D. PropScatter3D and PropScatter2D
## read the same rules; the same rules and seed give the same props.

## The seed of the noise and of every random roll.
@export var random_seed := 1

@export_group("Clusters")
## Across of a typical cluster (world units): the noise's period.
@export_range(1.0, 10000.0, 1.0, "or_greater") var cluster_size := 200.0
## How much of the ground the clusters cover: 0 none, 1 all of it (an even scatter).
@export_range(0.0, 1.0, 0.01) var cover := 0.35
## How soft a cluster's edge is: wider = more props thinning out into the open.
@export_range(0.01, 0.5, 0.01) var edge := 0.15
## Chance of a prop inside a cluster (1 = as packed as `spacing` lets them).
@export_range(0.0, 1.0, 0.01) var density := 0.8
## Chance of a lone prop out of the clusters.
@export_range(0.0, 1.0, 0.005) var lone_chance := 0.01

@export_group("Props")
## Room between two props of scale 1, centre to centre (world units). It grows with their scale.
@export_range(0.01, 1000.0, 0.01, "or_greater") var spacing := 8.0
## Scale at a cluster's edge (x) and at its heart (y).
@export var scale_range := Vector2(0.7, 1.4)
## Random part of the scale on top of the cluster's (0.2 = up to 20 % bigger or smaller).
@export_range(0.0, 0.9, 0.01) var scale_jitter := 0.15
## How much smaller props get near a keep-out (0 = no change, 0.25 = a quarter smaller at its edge).
@export_range(0.0, 0.9, 0.01) var keep_out_shrink := 0.25
## A random turn for each prop: around up in 3D, the rotation in 2D.
@export var random_rotation := true
## The most props one scatter plants. The cut falls at cluster edges first.
@export_range(1, 100000, 1, "or_greater") var max_count := 2000
## Tries per prop that `spacing` fits over the area: more = closer to `density`, slower.
@export_range(1.0, 10.0, 0.5) var tries := 3.0

@export_group("3D")
## How far into the ground, times the prop's scale (world units): no gap under it on a slope.
@export_range(0.0, 10.0, 0.01, "or_greater") var sink := 0.0
## How much a prop leans with the ground: 0 straight up, 1 square to the slope.
@export_range(0.0, 1.0, 0.01) var align_to_normal := 0.0
