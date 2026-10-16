class_name BenchEvent
extends Resource

## Something the bench does at a second of the match and what it measures about it (RFC-024 024c, §6). The AI is not told:
## the runner puts the body on the field, the AI has to find out by itself.
##   spawn  a creature `tag` of `slot` at `distance_m` of the wizard of `from_slot`, on the side of angle `angle_deg` (0 = towards
##          the other wizard); `npc` joins the group `npc` (a Farmer of the map).
##   kill   the body named `victim` under %Units dies at that second.
## `watch` says what the report reads about it: «tracked» (is it in the perception of `from_slot`?), «attacked» (the first
## tick a creature of `from_slot` has it as a target, and the first tick it was within sight of one), «untracked» (ticks until
## the perception of `from_slot` drops the victim).

@export var at_s := 60.0
@export_enum("spawn", "kill") var action := "spawn"
@export var label := "event"
@export var tag := "ycro"
@export var slot := 1
@export var npc := false
@export var from_slot := 2
## What the distance is measured from: «wizard» (where he is now), «altar» (the altar of `from_slot`, fixed) or «structure» (its first
## structure, the Manalith, fixed). The AI scenes use the fixed ones: the wizard walks, so the event would land somewhere else each run.
@export_enum("wizard", "altar", "structure") var anchor := "wizard"
@export var distance_m := 600.0
@export var angle_deg := 0.0
@export var victim := ""
@export_enum("none", "tracked", "attacked", "untracked") var watch := "none"
