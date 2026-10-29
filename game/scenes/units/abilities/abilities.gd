class_name Abilities
extends Node

## What a creature can do on command: its active ability (`slot`) and the door the orders come
## through (`port`). The ability itself is the AbilityType of the creature; what it does is that
## type's effect scene.
## Not: the checks and the cost (AbilitySlot) nor the order and its network hop (AbilityPort).
## Edit: set `active_ability` on the CreatureType and give its AbilityType an `effect` scene; this
## node does not change.

## The creature's active ability.
@export var slot: AbilitySlot
@export var port: AbilityPort
## What the ability spends.
@export var mana: ManaPool


## Hands the slot the creature, which builds the effect of its ability. Once, when the body is
## ready.
func setup(unit: UnitBody, creature: CreatureType) -> void:
	slot.setup(unit, creature, mana)
