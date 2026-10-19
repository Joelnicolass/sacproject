class_name DeathCloudType
extends Resource

## F118 (RFC-030g): what a creature leaves when it dies, for one passive SpellTag of its CRE8 (goc@, cen@, tum@). The numbers
## (amount, damage_range, effect_range, duration) are the SPEL's: the cloud reads them from GameData.ability(tag). Here only
## which scene does it and how it looks. A new cloud is a new .tres (and, if it does something new, a new scene).

## SpellTag as CreatureType.passive_abilities holds it.
@export var tag: String = ""
## A DeathCloud scene: what the cloud does to the bodies around it.
@export var scene: PackedScene
## ParticleType of data/fx played once where the body died (FxBus, every peer). Empty = no puff.
@export var fx_name: String = ""
## Height of the puff over the body's center, in meters.
@export var fx_height_m: float = 0.0
