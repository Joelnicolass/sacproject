class_name AbilityType
extends BookEntry

## One active ability of a creature (Viscous Oil, Run Away...): what it costs, how far it reaches, who it aims at, and the scene that
## does it. It does NOT run anything (the AbilityEffect scene does) and it never changes at run time.

## What the ability does when a creature uses it on command: the scene of an AbilityEffect (scenes/units/abilities/). Empty = «No
## implementado». A new active ability is a new scene dropped here, never a new branch in code.
@export var effect: PackedScene
## How a shot of this ability looks and what it does in flight and on arrival: a scene of data/shots/ whose root is a ShotLook.
## Required when a creature fires this ability as its ranged attack (RangedWeapon); empty for every other ability.
@export var shot_look: PackedScene
## How far from the caster it can be cast (m).
@export var cast_range_m: float = 0.0
## Speed of what it sends (m/s).
@export var speed_m_s: float = 0.0
## Acceleration of what it sends (m/s²).
@export var acceleration_m_s2: float = 0.0
@export var damage: int = 0
## Radius of its damage around where it hits (m).
@export var damage_range_m: float = 0.0
## Reach of its effect (m).
@export var effect_range_m: float = 0.0
## How long its effect lasts (s).
@export var duration_s: float = 0.0
@export_group("Who it aims at")
## An ability with none of these on fires at once, without asking for a target; with any, the player picks one first.
@export var targets_wizards := false
## Breath of Life style: it looks for souls (after the living body under the cursor).
@export var targets_souls := false
@export var targets_creatures := false
## Breath of Life style: it looks for corpses (after the souls).
@export var targets_corpses := false
@export var targets_structures := false
@export var targets_ground := false

@export_group("AI")
## The AI rates it as an attack on creatures (only if it also targets creatures) when it sizes up a body.
@export var ai_attack := false
## What the AI's rater adds per ability, before range and mana: bigger is a better ability.
@export var ai_worth := 0

@export_group("Poison")
## Thousandths of resistance a dose takes off the target (0 = none). Only poison abilities read it.
@export var poison_resistance_debuff := 0
## Multiplier of the target's regeneration while the dose lasts (1 = unchanged, 0 = none). Only poison abilities read it.
@export var poison_regen_factor := 1.0


## True when the player must pick a target before the ability fires.
func needs_target() -> bool:
	return targets_wizards or targets_souls or targets_creatures or targets_corpses or targets_structures or targets_ground


## True when it looks for souls or corpses, not only for living bodies.
func aims_at_dead() -> bool:
	return targets_souls or targets_corpses


## True when the AI counts it as an attack on creatures.
func is_creature_attack() -> bool:
	return ai_attack and targets_creatures
