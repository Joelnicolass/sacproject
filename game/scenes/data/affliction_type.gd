class_name AfflictionType
extends Resource

## F120 (RFC-030i): what a state that takes a creature out of the fight (stunned, petrified, later frozen) means to
## the rest of the body. One .tres per state; the Affliction child of Afflictions that plays it points here. Afflictions
## is the only one that answers the body's questions, by these flags of the states that are on.

## The state's name in the log and in `cancels`.
@export var id: StringName = &""
## Its bit in Afflictions.shown (the mask replicated to the clients). One bit per type.
@export_range(0, 30) var bit := 0
## No AI, no orders carried out, no attacks, no turning, no ability (sacengine stunned: the mode switch skips them).
@export var holds := true
## Not even pushed: no separation and no pose (petrified, `effects.immobilized`).
@export var immobilizes := false
## A flier falls while it lasts (sacengine petrify startTumbling, state.d:11636): Flight lets gravity take it down to
## the ground and the body goes back up to its height when it ends. Off: a flier hangs where it is (stunned).
@export var drops_fliers := false
## Ends the body's own special mode when it starts (Rockform: sacengine petrify sets mode = stunned, state.d:11631-11640),
## so the rock's ×0.05 does not stack and the end can knock it down. The body reads it (UnitBody, on held_changed).
@export var breaks_special_modes := false
## Multiplies every hit the body takes while it lasts (petrified ×0.2, state.d:8965). Stunned: 1.
## Only for shields (dealDamage's `!peirceShield` block, state.d:8962-8969): a pierce_shield hit (the Pyromaniac's fire,
## F123) skips it in Health. A state whose factor is not a shield needs its own field, not this one.
@export var damage_factor := 1.0
## Refuses the crowd control that asks ccProtected (petrify, state.d:11631-11640).
@export var cc_protects := false
## The ids of the states this one ends when it starts. A state that is on refuses a new one unless the new one
## cancels it, so who wins is said here, not by the order of the children (sacengine canStun refuses `stunned`).
@export var cancels: Array[StringName] = []
## F149: the mesh look while it is on (Afflictions.look, one StoneLook per body): a tint of the stone shader. Off: the
## state draws nothing on the mesh. Among the states that are on, the highest look_priority wins (petrified over frozen).
@export var has_look := false
@export var look_tint := Color(1.0, 1.0, 0.8)
@export var look_priority := 0
