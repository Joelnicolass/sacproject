@tool
class_name VegetationQuality
extends Resource

## How much one vegetation layer draws in one quality preset. `LookQuality.vegetation` holds one per
## layer (`layer_id` = the VegetationLayerConfig's `id`); a preset without an entry for a layer does
## not draw it.

@export var layer_id: StringName = &"original_plants"
@export var enabled := true
## Multiplies the layer's `radius_m` (and its tier distances).
@export_range(0.1, 2.0, 0.05) var radius_scale := 1.0
## Multiplies the plants of every cell (FloraPlacement.instance_count: stochastic rounding, never
## off by 1 or more).
@export_range(0.0, 2.0, 0.05) var density_scale := 1.0
## Off: no species of the layer casts a shadow, whatever its own `cast_shadow` says.
@export var shadows := false
## Most cells (32 m) planned at once on worker threads; the nearest go first. Applying them is
## bounded by FloraField.build_budget_ms.
@export_range(1, 16) var max_builds_per_frame := 2
