class_name BenchGroup
extends Resource

## One group of creatures of a bench match (RFC-024 §6 024a): `count` bodies of `tag` for `slot`, in
## `columns` columns `spacing_m` apart, `offset_m` along the X axis from BenchRules.anchor, looking
## along `facing_x` (+1 = towards +X, -1 = towards -X).

@export var tag := "ycro"
@export var slot := 1
@export var count := 6
@export var columns := 3
@export var spacing_m := 3.0
@export var offset_m := 0.0
## F116: along the Z axis from BenchRules.anchor (a row of different creatures side by side).
@export var offset_z_m := 0.0
@export var facing_x := 1.0

## Placement relative to a wizard (RFC-024 024c): with `near_slot` > 0 the group stands `near_distance_m` from the wizard of that
## slot, towards the wizard of the other slot turned `near_angle_deg`, and `offset_m` is ignored.
@export var near_slot := 0
@export var near_distance_m := 0.0
@export var near_angle_deg := 0.0
## "advance_altar": the group is ordered (Orders.apply_for, like a human's) to advance to the altar of `order_slot`.
@export var order := ""
@export var order_slot := 2
## F117: each body starts with this fraction of its health (1 = full). The bench writes Health.current once, before the record starts.
@export_range(0.01, 1.0, 0.01) var health_fraction := 1.0
