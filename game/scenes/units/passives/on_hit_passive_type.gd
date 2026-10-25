class_name OnHitPassiveType
extends CreaturePassive

## A passive that fires when its owner's melee blow connects, even if the damage roll fails: the Yeti's Freeze and the Dragon's
## Grasping Vines. MeleeOnHit walks the creature's `passives` and, for each one of this kind, calls Affliction.inflict(spell, slot)
## on the Affliction it finds at `affliction_path` under the target. A new on-hit passive is a new .tres, not an `if`; a passive
## with its own rule beyond these knobs gets its own component.
## Ref: sacengine updateCreatureAttack (state.d:14411-14438).

## The spell the affliction takes (data/catalog/spells/zerf.tres, eniv.tres).
@export var spell: SpellType
## The Affliction under the target body ("Afflictions/Frozen").
@export var affliction_path := NodePath("")
## graspingVines refuses a flier (10795-10812); Freeze does not.
@export var refuse_flying := false
## Freeze (14411-14438): `canFreeze = !frozen_before && valid_after`; a blow on a body that was already frozen does not
## freeze it again (it breaks the ice). Off for the Vines.
@export var skip_if_was_frozen := false
