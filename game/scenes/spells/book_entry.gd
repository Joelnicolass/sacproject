@tool
class_name BookEntry
extends Resource

## What every entry a wizard or a creature can cast has in common: a spell (SpellType), a creature
## to summon (CreatureType) or a creature ability (AbilityType). Caster, CastTime and Spellbook read
## these fields without asking which kind it is. It is never used on its own: a `.tres` is always
## one of the three types.

## Id of the entry on the network and in the catalog.
@export var tag: String = ""
## The name a player reads (book, roster, info box, cast feedback).
@export var display_name: String = ""
## The picture of the entry in the book, on the roster and on the cursor while it waits for its
## target. Drag any PNG here to change it. Empty: the tag is written instead.
@export var icon: Texture2D
## Mana it costs to cast.
@export var mana_cost: int = 0
## Seconds before it can be cast again.
@export var cooldown_s: float = 0.0
## Seconds the cast lasts at the entry's own level (CastTime shortens it for a wizard of a higher
## level).
@export var casting_time_s: float = 0.0
