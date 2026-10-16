class_name VillageRules
extends MatchRules

## MatchRules of the village test bed (debug/village.tscn, RFC-024 addendum 1, 024b2): the round rules of the
## parent plus where the human wizard and his Druid `Hunter` stand and what the bed does with the NPC.

## The human wizard stands this far from the focus (the hut `focus_hut` or the NPC `focus_npc`), on the side
## of `from_direction` (X, Z of the map, normalized).
@export var wizard_distance_m := 30.0
@export var from_direction := Vector2(0.0, -1.0)
## The hut the wizard looks at (a jhut of the NTTS, ground x and z).
@export var focus_hut := Vector2(1255.0, 1214.0)
## Name of an NPC to stand beside instead of the hut («Farmer6» lives more than 50 m from every shelter).
@export var focus_npc := ""
## Hunter stands this far from the wizard, to the side (perpendicular to `from_direction`), so the wizard is not in its way.
@export var hunter_offset_m := 4.0
## > 0: Taurock1 is put this far from Hunter (along +X) when the bed starts.
@export var taurock_gap_m := 0.0
## The NPC wait (process off) until check_tick (Enter).
@export var pause_npcs := true
## With `taurock_gap_m`: every NPC but Taurock1 is taken off the field, so the Taurock has no Farmer to pick (they are
## its enemies by the SIDS) and the bed measures whether it picks and attacks Hunter.
@export var isolate_taurock := true
