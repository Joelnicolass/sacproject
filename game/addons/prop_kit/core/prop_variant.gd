@tool
class_name PropVariant
extends Resource

## One kind of prop a scatter plants: its scene, and how often it comes up next to the others.

## The prop: a Node3D scene for PropScatter3D, a Node2D scene for PropScatter2D.
@export var scene: PackedScene
## How often, relative to the other variants (2 = twice as often as one of weight 1).
@export_range(0.0, 100.0, 0.01, "or_greater") var weight := 1.0


## One weight per variant, for PropPlanner.plan.
static func weights_of(variants: Array[PropVariant]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for variant in variants:
		out.append(variant.weight)
	return out
