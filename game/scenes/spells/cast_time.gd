class_name CastTime
extends RefCounted

## Casting time of a book entry for a wizard level, like sacengine `castingTime(level)` (sacspell.d:93-102):
## the entry's frames (counted at 1.35 x 60 per second) lose 10 % per level the wizard has over the entry's level
## (spell_order / 100), at most 5 levels, with integer division. The Basilisk casts in 19/20 of its frames.
## With no bonus (and not the Basilisk) it is the exported casting_time_s untouched.

## sacengine `frames/(1.35f*60.0f)`; tools/import/export_stats.py CAST_FRAMES_PER_SECOND.
const FRAMES_PER_SECOND := 1.35 * 60.0
const MAX_BONUS := 5
const BASILISK := "guls"


## `entry` is a CreatureType or SpellType (anything with casting_time_s, spell_order and tag).
static func seconds(entry: Resource, wizard_level: int) -> float:
	if entry == null:
		return 0.0
	var base := float(entry.get("casting_time_s"))
	var bonus := bonus_levels(entry, wizard_level)
	var basilisk := str(entry.get("tag")) == BASILISK
	if bonus == 0 and not basilisk:
		return base
	var count := roundi(base * FRAMES_PER_SECOND)
	if basilisk:
		@warning_ignore("integer_division")
		count = 19 * count / 20
	@warning_ignore("integer_division")
	count = (count * 10 - count * bonus) / 10
	return count / FRAMES_PER_SECOND


## Original casting frames (1.35 x 60 per second) for a level, for logs and checks.
static func frames(entry: Resource, wizard_level: int) -> int:
	return roundi(seconds(entry, wizard_level) * FRAMES_PER_SECOND)


static func bonus_levels(entry: Resource, wizard_level: int) -> int:
	var order_value: Variant = entry.get("spell_order")
	@warning_ignore("integer_division")
	var spell_level := int(order_value) / 100 if order_value != null else 0
	return mini(MAX_BONUS, maxi(0, wizard_level - spell_level))
