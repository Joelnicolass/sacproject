class_name DeathCloudType
extends CreaturePassive

## What a creature leaves when it dies: a cloud that hurts or heals the bodies around it. The numbers (amount, damage range,
## effect range, duration) are the `ability`'s; here only which scene does it and how it looks. A new cloud is a new .tres (and, if
## it does something new, a new scene) that the creature lists in `CreatureType.passives`.
## Ref: sacengine kill() runs the clouds of passiveAbility / passiveAbility2 (state.d:8274-8278).

## The numbers of the cloud (data/catalog/abilities/goc@.tres, cen@.tres, tum@.tres).
@export var ability: AbilityType
## A DeathCloud scene: what the cloud does to the bodies around it.
@export var scene: PackedScene
## The puff played once at the center of the dead body's box (FxBus, every peer). Empty = no puff.
@export var fx: ParticleType
