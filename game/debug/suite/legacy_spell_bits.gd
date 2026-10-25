extends RefCounted

## What the AI decided from the flag words of a spell before 055e, copied literally so spell_field_cases can prove the named fields give
## the same decisions. A row is one line of spell_bits_055e.csv (tag, flags, flags1, flags2, amount2, count, effect_range_m,
## ai_use_before) as ints and floats. It dies with debug/ when the refactor ends. Preloaded by path (no class_name).
## Ref: ai_spell_eval.gd and wizard_brain.gd at 20f109a0, shiny.d:322-345, 2656-2661, 2756-2797.

const ATTACK_MASK := 0x58000000
const SUPPORT_MASK := 0xa4000000
const FN_NONE := 0
const FN_SINGLE := 1
const FN_AREA := 2
const FN_HEAL := 3
const FN_SPEEDUP := 4
const FN_GUARD := 5
const FN_DISABLE := 6
const TYPE_WIZ := 1
const TYPE_CRE := 4
const TYPE_STR := 0x10


static func wants_acc(row: Dictionary) -> bool:
	return (int(row["flags1"]) & 0xfc00) != 0


## `ai_use_before` was the SELF_GUARD (1) / DISABLE_FOE (2) of the cuts 061b and 061c.
static func rating_fn(row: Dictionary) -> int:
	if int(row["ai_use_before"]) == 1:
		return FN_GUARD
	if int(row["ai_use_before"]) == 2:
		return FN_DISABLE
	match str(row["tag"]):
		"laeh":
			return FN_HEAL
		"pups":
			return FN_SPEEDUP
		"omna", "ndrg", "elet", "ccas", "taed":
			return FN_NONE
	var f1 := int(row["flags1"])
	if f1 & 0x4000:
		return FN_AREA if ((f1 & 0x40) != 0 and float(row["effect_range_m"]) > 0.0) else FN_SINGLE
	if f1 & 0x8000:
		return FN_HEAL
	return FN_NONE


static func accepts(row: Dictionary, mask: int) -> bool:
	return (((int(row["flags1"]) << 16) | 0) & mask) != 0


static func only_on_self(row: Dictionary) -> bool:
	return (int(row["flags1"]) & 0x10) != 0


## The kind filter of `rate`: `type_bits` is TYPE_WIZ, TYPE_CRE, TYPE_STR or 0.
static func lands_on(row: Dictionary, type_bits: int) -> bool:
	var mask := int(row["flags"]) & 0x781f
	return not (mask != 0 and (type_bits & mask) == 0)


## `can_cast_on` over looked-up facts (relation: 0 own, 1 ally, 2 or 3 not an ally).
static func can_cast_on(row: Dictionary, free_fount: bool, relation: int, fount_structure: bool) -> bool:
	var flags := int(row["flags"])
	if flags == 0:
		return true
	if flags & 0x1f:
		if flags & (1 << 11):
			return free_fount
		if (flags & (1 << 12)) != 0 and relation > 1:
			return false
		if flags & (1 << 13):
			if relation <= 1:
				return false
			if fount_structure:
				return false
	return true


## The worth the rater added for the spell of a wizard's book (ai_rater.fill_from_object), or -1 if the spell did not count.
static func rater_worth(row: Dictionary, cast_range_m: float, mana_cost: float, mana_f: float, k: float) -> float:
	if (int(row["flags1"]) & 0xfc00) == 0:
		return -1.0
	var t := float(int(row["amount2"])) * cast_range_m
	var f := (mana_cost / mana_f if mana_f != 0.0 else 0.0) if mana_f > mana_cost else 1.0
	t *= (1.0 - f)
	return t * k
