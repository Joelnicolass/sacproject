@tool
class_name PropSpot
extends RefCounted

## One place a scatter plants a prop (PropPlanner.plan): where on the ground plane, how big, how
## turned and which variant. The ground plane is (x, z) in 3D and (x, y) in 2D.

## Where, on the ground plane, in global coordinates.
var at := Vector2.ZERO
## Uniform scale of the prop.
var scale := 1.0
## Turn around the up axis (3D) or the rotation (2D), in radians.
var angle := 0.0
## Index into the scatter's `variants`.
var variant := 0
## How deep in its cluster the spot is (the noise, 0..1): the planner plants the deepest first.
var depth := 0.0
