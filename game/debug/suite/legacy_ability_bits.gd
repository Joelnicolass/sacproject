extends RefCounted

## What the game decided from the flag words, `amount2` and `args` of an ability (and from `spell_order`) before 055e e6, copied literally
## so ability_field_cases can prove the named fields give the same decisions. A row is one line of ability_bits_055e6.txt (file, tag,
## flags, flags1, flags2, amount2, ires, freg; `ires` and `freg` are "" when the key was not in `args`). It dies with debug/ when the
## refactor ends. Preloaded by path (no class_name).
## Ref: ability_command.gd, ai_rater.gd, poison_cloud.gd and poison_impact.gd at 95f0de4c.


## ability_command.use: any flag at all means «pick a target first».
static func needs_target(row: Dictionary) -> bool:
	return int(row["flags"]) != 0


## ability_command._aims_at_dead: targetSouls (1 << 1) or targetCorpses (1 << 3).
static func aims_at_dead(row: Dictionary) -> bool:
	return (int(row["flags"]) & ((1 << 1) | (1 << 3))) != 0


## ai_rater.fill_from_object: only the attacks on creatures count (flags1 & 0x4000 and flags & targetCreatures).
static func counts_in_rater(row: Dictionary) -> bool:
	return (int(row["flags1"]) & 0x4000) != 0 and (int(row["flags"]) & 4) != 0


## AbilityType.arg_int("ires", 0) over the args.
static func ires(row: Dictionary) -> int:
	return int(float(str(row["ires"]))) if str(row["ires"]) != "" else 0


## AbilityType.arg_float("freg", 1.0) over the args.
static func freg(row: Dictionary) -> float:
	return float(str(row["freg"])) if str(row["freg"]) != "" else 1.0


## CastTime.bonus_levels with `spell_order / 100` as the level of the entry.
static func cast_bonus(spell_order: int, wizard_level: int) -> int:
	@warning_ignore("integer_division")
	var spell_level := spell_order / 100
	return mini(5, maxi(0, wizard_level - spell_level))
