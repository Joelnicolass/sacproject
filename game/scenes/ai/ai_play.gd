class_name AiPlay
extends RefCounted

## What one AI side plays with: its tactics, its difficulty and the aggression that comes with it,
## and how long an «age» of a track lasts. AiSide.setup makes it once from the seat and hands it to
## every child; nothing changes it after, and no `.tres` is ever changed. It decides nothing.

var tactics: AiTactics
var difficulty: AiDifficulty
var aggression := 1.0
## Ticks of one age: the perception job's period at Normal pace (not scaled), so a slower difficulty
## stretches the ages in time the same as it stretches its clock.
var age_ticks := 1


## The play of a seat: `p_tactics` when given (a seat's own personality), else the difficulty's.
static func make(p_difficulty: AiDifficulty, p_tactics: AiTactics, p_age_ticks: int) -> AiPlay:
	var play := AiPlay.new()
	play.difficulty = p_difficulty
	play.tactics = p_tactics if p_tactics != null else p_difficulty.tactics_or_normal()
	play.aggression = p_difficulty.aggression
	play.age_ticks = maxi(1, p_age_ticks)
	return play


## Normal's play with the clock's default perception period, for the parts of an AI built outside an
## AiSide (the suite).
static func normal() -> AiPlay:
	var clock := AiClock.new()
	var ticks := clock.base_ticks(AiClock.Job.PERCEPTION)
	clock.free()
	return make(AiSeat.NORMAL, null, ticks)


## Whole ages that `seconds` last at Normal pace (1.6 s at 60 Hz, ages of 6 ticks: 16).
func ages_for(seconds: float) -> int:
	@warning_ignore("integer_division")
	return MatchClock.ticks_for(seconds) / age_ticks
