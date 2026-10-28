class_name MusicMood
extends RefCounted

## Which music plays, as a pure function of what the player's process sees (MusicDirector gathers
## the inputs and plays; this decides). The rules, highest first:
## 1. the match has a result: `victory` or `defeat`, once (MusicDirector does not restart a
##    one-shot);
## 2. a desecration runs that involves the local side: `winning` (we desecrate) or `losing` (our
##    altar is desecrated);
## 3. a ritual runs within `ritual_radius_m` of the camera (70 m): `sacrifice`;
## 4. battle (CombatGauge: combat near the listener, or the local wizard hurt in the last 120 s):
##    `battle`;
## 5. otherwise the god's `calm` (its `normal` theme). The menu is always `calm` of the menu set.
## No node, no state, no randomness: music_mood_cases tries the table.

enum Result { NONE, WON, LOST }
enum Desecration { NONE, WINNING, LOSING }

const CALM := &"calm"
const BATTLE := &"battle"
const SACRIFICE := &"sacrifice"
const WINNING := &"winning"
const LOSING := &"losing"
const VICTORY := &"victory"
const DEFEAT := &"defeat"

const ALL: Array[StringName] = [CALM, BATTLE, SACRIFICE, WINNING, LOSING, VICTORY, DEFEAT]
## Moods whose track plays once and is not restarted when it ends.
const ONCE: Array[StringName] = [VICTORY, DEFEAT]


## The mood for these inputs.
static func decide(
	result: Result, desecration: Desecration, ritual_near: bool, battle: bool
) -> StringName:
	match result:
		Result.WON:
			return VICTORY
		Result.LOST:
			return DEFEAT
	match desecration:
		Desecration.LOSING:
			return LOSING
		Desecration.WINNING:
			return WINNING
	if ritual_near:
		return SACRIFICE
	if battle:
		return BATTLE
	return CALM


## The result as the local side sees it: none while the match runs (or with no side: a dedicated,
## slot 0).
static func result_of(has_result: bool, won: bool, local_slot: int) -> Result:
	if not has_result or local_slot <= 0:
		return Result.NONE
	return Result.WON if won else Result.LOST


## What one running desecration means to the local side: LOSING when it is on our altar (it wins
## over our own: a side never desecrates itself, but the lab may), WINNING when we cast it, NONE
## when it is between others.
static func desecration_of(caster_slot: int, target_slot: int, local_slot: int) -> Desecration:
	if local_slot <= 0:
		return Desecration.NONE
	if target_slot == local_slot:
		return Desecration.LOSING
	if caster_slot == local_slot:
		return Desecration.WINNING
	return Desecration.NONE


## Of several desecrations, the one that matters most (LOSING over WINNING over NONE).
static func worst(a: Desecration, b: Desecration) -> Desecration:
	if a == Desecration.LOSING or b == Desecration.LOSING:
		return Desecration.LOSING
	if a == Desecration.WINNING or b == Desecration.WINNING:
		return Desecration.WINNING
	return Desecration.NONE


static func is_once(mood: StringName) -> bool:
	return ONCE.has(mood)
