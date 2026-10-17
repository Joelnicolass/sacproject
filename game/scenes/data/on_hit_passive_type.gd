class_name OnHitPassiveType
extends Resource

## One passive that fires when its owner's melee blow connects (sacengine updateCreatureAttack, state.d:14411-14438: on
## every attack tick with a target, even if the damage roll fails): the Yeti's Freeze (zerf) and the Dragon's Grasping
## Vines (eniv). The tag is the SpellTag, as CreatureType.passive_on_hit holds it; MeleeOnHit looks the type up by it and
## calls Affliction.inflict(GameData.spell(tag), slot) on the target's Affliction found at `affliction_path`. A new
## on-hit passive is a new .tres, not an `if tag` (a passive with its own rule beyond these knobs gets its own component).

## SpellTag of the passive.
@export var tag := ""
## The Affliction under the target body ("Afflictions/Frozen").
@export var affliction_path := NodePath("")
## graspingVines refuses a flier (10795-10812); Freeze does not.
@export var refuse_flying := false
## Freeze (14411-14438): `canFreeze = !frozen_before && valid_after`; a blow on a body that was already frozen does not
## freeze it again (it breaks the ice). Off for the Vines.
@export var skip_if_was_frozen := false
