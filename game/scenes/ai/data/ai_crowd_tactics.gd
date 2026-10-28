class_name AiCrowdTactics
extends Resource

## How the AI moves its creatures: how close bodies form a group, when a record's members think
## alone, where followers and guards stop, how far a body looks for mana, which creature goes with
## the wizard to an altar, and the focus of the side. It does not choose the wizard's spells
## (AiTactics). Embedded in each data/ai/tactics_*.tres; never changed while playing. The numbers
## are the original's, except the deviations named on each field.
## Ref: shiny.d:1702-1710 canAccept, 3419 and 3433 recordUpdate, 2376 retreat (state.d:13608
## retreatDistance), 2552 autoCapture, 2565 orderInteract, 3026-3050 pickGuardCreature.

@export_group("Groups")
## A group of n takes a body within group_radius_m * min(1 + group_growth * n, group_cap) of its
## center, in meters.
@export var group_radius_m := 30.0
## See group_radius_m: how much each member widens the group.
@export var group_growth := 0.1
## See group_radius_m: the most a group widens.
@export var group_cap := 1.8

@export_group("Records")
## A record whose members are all within this of its center lets each member think by itself (the
## original compares 10000 = 100 m squared).
@export var record_near_m := 100.0
## Followers of a record's leader hold where they stand once this close to him. Deviation (the
## original passes 0): pressed onto the wizard's spot they shoved him off his altar (measured: 70 m
## in 3 min).
@export var follow_radius_m := 8.0
## A creature on guard of a body stops this far from it and fights from there (the engine's retreat
## distance). Deviation: the port's tight guard formation stacked them on the wizard.
@export var retreat_hold_m := 10.0

@export_group("Capture and refill")
## A body that needs mana looks for a Manahoar or a mana building within this.
@export var mana_seek_m := 3620.0
## A capture record sends a creature to its anchor until it is within (1 - value) * this, in
## meters.
@export var interact_reach_m := 160.0
## A body that went to a mana source at its minimum stays until it holds this fraction of its pool.
## 0: the original (it leaves as soon as it is over the minimum, and comes back after one spell).
@export_range(0.0, 1.0, 0.05) var mana_refill_ratio := 0.5

@export_group("Altar guard")
## The creature brought next to the wizard for Desecrate weighs 1 within near, falling linearly to
## 0 at far, times its souls.
@export var guard_pick_near_m := 10.0
## See guard_pick_near_m.
@export var guard_pick_far_m := 3620.0

@export_group("Focus")
## A target is focused only if the side can kill it in this many seconds.
@export_range(0.0, 120.0, 1.0) var focus_kill_window_s := 20.0
## A target is focused only if the local strength is over this ratio.
@export_range(0.0, 10.0, 0.1) var focus_power_ratio := 1.2
## Candidates: known enemies within this distance of an own group.
@export_range(0.0, 500.0, 5.0) var focus_radius_m := 60.0
## Creatures a focus claims at most.
@export_range(0, 32) var focus_max_members := 6
## What an enemy wizard is worth among the candidates, in souls (a creature is worth its souls):
## killing him stops his casts.
@export_range(0.0, 20.0, 0.5) var focus_wizard_worth := 4.0
