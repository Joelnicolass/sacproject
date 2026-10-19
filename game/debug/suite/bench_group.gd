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
## "attack_unit" (F136): the group is ordered to attack the creature of `order_slot` closest to its first body.
## "ability" (F137): each body uses its active ability on itself when the clock starts (Rockform).
## "advance_altar": the group is ordered (Orders.apply_for, like a human's) to advance to the altar of `order_slot`.
## "move" / "guard_area" (F370): the group is ordered to walk to / to hold `order_point` (from the group's own center).
@export var order := ""
@export var order_slot := 2
## F148: "attack_unit" picks the creature of `order_slot` farthest from the group's first body instead of the closest
## (an Abomination shooting over the Druids that stand under its gut's flight).
@export var order_farthest := false
## F148: each body gets a copy of its CreatureType with aggressiveness 0 (a pacifist, sacobject.d:84): it never picks a
## foe, so Druids stay where the bench put them (under the gut's flight) instead of running at the shooter.
@export var pacifist := false
## F117: each body starts with this fraction of its health (1 = full). The bench writes Health.current once, before the record starts.
@export_range(0.0001, 1.0, 0.0001, "or_less") var health_fraction := 1.0
## F131: each body never picks a foe by itself (UnitBody.idle_aggro off): it stays where the bench put it until an order (an `attack`
## event) sends it. A body that still has aggressiveness: unlike a pacifist it obeys «attack».
@export var holds_still := false
## F370: the name BenchExpect calls this group by (subject / object). Empty: the tag.
@export var label := ""
## F370: a creature of the map (UnitSpawner.spawn_map_creature): a peasant tag gets the peasant scene, and it joins `npc`.
@export var npc := false
## F370: where "move" and "guard_area" point, X and Z in meters from the group's center (anchor + offset_m, offset_z_m).
## Zero: the group's own center.
@export var order_point := Vector2.ZERO


## The name of the group for BenchExpect.
func key() -> String:
	return label if not label.is_empty() else tag
