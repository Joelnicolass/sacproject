class_name DeathCloudType
extends Resource

## What a creature leaves when it dies: a cloud that hurts or heals the bodies around it. The
## numbers (amount, damage range, effect range, duration) are the `ability`'s; here only which scene
## does it and how it looks. A new cloud is a new .tres (and, if it does something new, a new scene)
## in the `clouds` of the creature's DeathCloudSpawner (its `<name>_passives.tscn`).

## The numbers of the cloud (scenes/units/abilities/steam_cloud.tres, cen@.tres, tum@.tres).
@export var ability: AbilityType
## A DeathCloud scene: what the cloud does to the bodies around it.
@export var scene: PackedScene
## The puff played once at the center of the dead body's box (FxBus, every peer). Empty = no puff.
@export var fx: ParticleType
