class_name BenchEvent
extends Resource

## Something the bench does at a second of the match and what it measures about it (RFC-024 024c, §6). The AI is not told:
## the runner puts the body on the field, the AI has to find out by itself.
##   spawn  a creature `tag` of `slot` at `distance_m` of the wizard of `from_slot`, on the side of angle `angle_deg` (0 = towards
##          the other wizard); `npc` joins the group `npc` (a Farmer of the map).
##   kill   the body named `victim` under %Units dies at that second.
##   ability  the body named `user` uses its active ability (like a click) on the point `point` (x, z of the map; the land's
##          height is taken) and on the body named `target` when there is one. The refusal goes to the log with the body's name.
##   attack  F129: the body named `user` (of `slot`) is ordered to attack the body named `target` (Orders.apply_for, like a click);
##          `point` is where the order is given when there is no target.
## `watch` says what the report reads about it: «tracked» (is it in the perception of `from_slot`?), «attacked» (the first
## tick a creature of `from_slot` has it as a target, and the first tick it was within sight of one), «untracked» (ticks until
## the perception of `from_slot` drops the victim).

@export var at_s := 60.0
@export_enum("spawn", "kill", "ability", "stun", "attack") var action := "spawn"
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
##   stun   the body named `user` is stunned for 120 ticks (Stunned.stun_with_cooldown): it cuts a preparation.
## F152, action "ability": the body that uses it, the body it is aimed at ("" = none) and the point (x, z of the map).
@export var user := ""
@export var target := ""
@export var point := Vector2.ZERO
## F129, action "attack": the order the body is given (Orders.COMMANDS). A pacifist (aggressiveness 0) refuses "attack" and "advance": it walks with "move".
@export_enum("attack", "move", "advance") var order := "attack"
