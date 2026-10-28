class_name CaptiveRules
extends RefCounted

## What a creature looks like when a doctor takes it, pumps it or lets it go: a pure table from a change of mode. CaptiveLook asks
## it and does what it answers; nothing here touches a node. A death is not answered here (CorpseLook owns it).

## What to show. NONE: nothing (a death, or a change that is not about a doctor). HANG: dangle as a rag doll. HANG_APPEAR: the same,
## fading in. KEEP_LYING: a pumped corpse stays where it fell. CLIPS: the held clips (rise, held, thrash). STAND_APPEAR: stand up
## and fade in. LET_GO: back to the creature's own clips.
enum Look { NONE, HANG, HANG_APPEAR, KEEP_LYING, CLIPS, STAND_APPEAR, LET_GO }


## `can_hang`: the model has a rag doll that can hang and the look may use it. `lies_as_ragdoll`: the body lies as a rag doll now.
## `was == now` is a late join (the model was mounted while the mode already held).
static func on_change(
	was: UnitBody.Mode, now: UnitBody.Mode, can_hang: bool, lies_as_ragdoll: bool
) -> Look:
	match now:
		UnitBody.Mode.DEAD:
			return Look.NONE
		UnitBody.Mode.HELD:
			if was == UnitBody.Mode.REVIVING and can_hang:
				return Look.HANG_APPEAR
			return Look.HANG if can_hang else Look.CLIPS
		UnitBody.Mode.REVIVING:
			if was != UnitBody.Mode.DEAD:
				return Look.CLIPS
			return Look.KEEP_LYING if lies_as_ragdoll else Look.STAND_APPEAR
	if was == UnitBody.Mode.REVIVING:
		return Look.STAND_APPEAR if lies_as_ragdoll else Look.LET_GO
	return Look.LET_GO if was == UnitBody.Mode.HELD else Look.NONE
