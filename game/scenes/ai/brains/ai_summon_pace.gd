class_name AiSummonPace
extends RefCounted

## The difficulty's own summon pace (Easy): a summon only after `interval_ticks` since the last one, and only if it leaves the
## wizard `mana_reserve` of his pool. 0 and 0 = the original (Normal, Hard). It does not summon: the summon phase asks it and
## Casting notes each summon it starts. Adenda 1.3 (AiDifficulty.summon_interval_s, mana_reserve).

## Set by AiSide.setup.
var interval_ticks := 0
var mana_reserve := 0.0
## The port tick of the last summon he started (the summon interval counts from it).
var _last_summon_tick := -1000000


func note_summon(now_tick: int) -> void:
	_last_summon_tick = now_tick


## The summon interval has passed since his last summon (always true with interval 0).
func interval_over(now_tick: int) -> bool:
	return interval_ticks <= 0 or now_tick - _last_summon_tick >= interval_ticks


## A creature of `mana_cost` leaves him at least the reserve (always true with reserve 0).
func keeps_reserve(wizard: AiTrack, mana_cost: float) -> bool:
	if mana_reserve <= 0.0:
		return true
	return AiBody.mana_now(wizard.node) - mana_cost >= mana_reserve * AiBody.mana_max(wizard.node)
