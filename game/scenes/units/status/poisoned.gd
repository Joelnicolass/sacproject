class_name Poisoned
extends DamageOverTime

## One dose of poison, a child of the body's Poisoning (the one owner of what the doses add up to,
## and of their order). Each dose deals its damage/60 per frame, always ignoring friendly fire, and
## ends after the update whose frame reached `lifetime`: lifetime + 1 updates (DamageOverTime.step).
##
## What a dose carries besides the damage: it may be `infectious` (the Necryl's Disease), it adds
## `resistance_debuff` to the body's poison resistance (×1e-3 to every resistance) and multiplies
## its regeneration by `regeneration_factor`. From its update at frame `mana_block_frame`
## (Poison.manaBlockDelay, 2 s) until it ends it blocks the body's mana. Poisoning reads these to
## answer Health, ManaPool and MeleeWeapon; the dose itself only deals its damage.

var infectious := false
## Resistance debuff (SPEL `ires`): poison resistance += it while the dose lasts.
var resistance_debuff := 0
## Regeneration factor (SPEL `freg`): regeneration *= it while the dose lasts.
var regeneration_factor := 1.0
## Frames after which the dose blocks the mana: 2 s.
var mana_block_frame := 120
## Set on the update whose frame is mana_block_frame; the block lasts until the dose ends.
var blocks_mana := false


func _before_damage() -> void:
	if frame == mana_block_frame:
		blocks_mana = true


func _log_word() -> String:
	return "poison"
