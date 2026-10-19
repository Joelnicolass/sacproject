class_name Poisoned
extends DamageOverTime

## F118 (RFC-030g), F122 (RFC-030k-a): one dose of poison, a child of the body's Poisoning (the one owner of what the doses
## add up to, and of their order). sacengine poison() (state.d:11601-11614) adds a Poison effect per dose; updatePoison
## (state.d:23535-23590) deals poisonDamage/60 per frame through dealPoisonDamage (state.d:9415-9419), which always passes
## ignoreFriendly, and ends after the update whose frame reached `lifetime`: lifetime + 1 updates (DamageOverTime.step).
##
## What a dose carries besides the damage (sacengine Poison): it may be `infectious` (the Necryl's Disease), it adds
## `resistance_debuff` to the body's poisonResistance (×1e-3 to every resistance, state.d:8950) and multiplies its
## regeneration by `regeneration_factor` (state.d:14403). From its update at frame `mana_block_frame` (Poison.manaBlockDelay,
## 2 s) until it ends it blocks the body's mana (numManaBlocks, state.d:23556-23558; giveMana, 8829). Poisoning reads these
## to answer Health, ManaPool and MeleeAttack; the dose itself only deals its damage.

var infectious := false
## sacengine Poison.resistanceDebuff (SPEL `ires`): poisonResistance += it while the dose lasts.
var resistance_debuff := 0
## sacengine Poison.regenerationFactor (SPEL `freg`): poisonRegeneration *= it while the dose lasts.
var regeneration_factor := 1.0
## sacengine Poison.manaBlockDelay = 2·updateFPS.
var mana_block_frame := 120
## Set on the update whose frame is mana_block_frame; the block lasts until the dose ends.
var blocks_mana := false


func _before_damage() -> void:
	if frame == mana_block_frame:
		blocks_mana = true


func _log_word() -> String:
	return "veneno"
