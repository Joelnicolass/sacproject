class_name CastTime
extends RefCounted

## Casting time of a book entry for a wizard level: the entry's frames (counted at 1.35 x 60 per
## second) lose 10 % per level the wizard has over the entry's level (book_level), at most 5 levels,
## with integer division. A creature with a `cast_time_factor` below 1 (the Basilisk, 0.95) first
## keeps that share of its frames, rounded down. With no bonus and no factor it is the exported
## casting_time_s untouched.

## Cast frames per second: `frames/(1.35f*60.0f)`; tools/import/export_stats.py
## CAST_FRAMES_PER_SECOND.
const FRAMES_PER_SECOND := 1.35 * 60.0
const MAX_BONUS := 5


static func seconds(entry: BookEntry, wizard_level: int) -> float:
	if entry == null:
		return 0.0
	var base := entry.casting_time_s
	var bonus := bonus_levels(entry, wizard_level)
	var factor_milli := _factor_milli(entry)
	if bonus == 0 and factor_milli == 1000:
		return base
	var count := roundi(base * FRAMES_PER_SECOND)
	@warning_ignore("integer_division")
	count = count * factor_milli / 1000
	@warning_ignore("integer_division")
	count = (count * 10 - count * bonus) / 10
	return count / FRAMES_PER_SECOND


## Original casting frames (1.35 x 60 per second) for a level, for logs and checks.
static func frames(entry: BookEntry, wizard_level: int) -> int:
	return roundi(seconds(entry, wizard_level) * FRAMES_PER_SECOND)


static func bonus_levels(entry: BookEntry, wizard_level: int) -> int:
	return mini(MAX_BONUS, maxi(0, wizard_level - BookOrder.level(entry)))


## The creature's cast_time_factor in whole thousandths (0.95 -> 950), so the frames are cut with
## integer division; 1000 for a spell.
static func _factor_milli(entry: BookEntry) -> int:
	var creature := entry as CreatureType
	return roundi(creature.cast_time_factor * 1000.0) if creature != null else 1000
