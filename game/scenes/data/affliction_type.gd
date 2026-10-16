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
## Multiplies every hit the body takes while it lasts (petrified ×0.2, state.d:8965). Stunned: 1.
@export var damage_factor := 1.0
## Refuses the crowd control that asks ccProtected (petrify, state.d:11631-11640).
@export var cc_protects := false
## The ids of the states this one ends when it starts. A state that is on refuses a new one unless the new one
## cancels it, so who wins is said here, not by the order of the children (sacengine canStun refuses `stunned`).
@export var cancels: Array[StringName] = []
