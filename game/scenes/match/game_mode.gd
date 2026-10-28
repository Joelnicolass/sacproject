@tool
class_name GameMode
extends Resource

## A way to play the match as a Resource: how many seats there are, which team each seat is on and
## how it is won. A new mode is a `.tres` of this script (data/modes/), no code. The mode is the
## room's choice, like the map; `MatchRules` stays the rules of the round (damage, times, friendly
## fire).

enum Victory { LAST_TEAM_STANDING }

## Short name used on the command line (`--mode=2v2`) and in room options.
@export var tag: StringName = &""
## Translation key of the name the screens show.
@export var display_name := ""
## Team of each seat, seat 1 first: [0, 1] is a 1v1, [0, 0, 1, 1] a 2v2, [0, 1, 2] three against
## each other. The number of seats is its size. Teams are numbered 0..T-1 with no gaps.
@export var team_of_seat: PackedInt32Array = PackedInt32Array([0, 1])
@export var victory: Victory = Victory.LAST_TEAM_STANDING
## False for modes the rooms do not offer.
@export var room_selectable := true


func seats() -> int:
	return team_of_seat.size()


## The team of a seat (1-based). A slot out of the mode's seats is its own team: `-seat` (every slot
## for itself).
func team_of(seat: int) -> int:
	if seat < 1 or seat > team_of_seat.size():
		return -seat
	return team_of_seat[seat - 1]


## Some team has two seats or more.
func has_allies() -> bool:
	var seen: Dictionary = {}
	for team in team_of_seat:
		if seen.has(team):
			return true
		seen[team] = true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if team_of_seat.is_empty():
		warnings.append("`team_of_seat` is empty: a mode needs at least one seat.")
		return warnings
	var seen: Dictionary = {}
	for team in team_of_seat:
		seen[team] = true
	for team in range(seen.size()):
		if not seen.has(team):
			warnings.append(
				"The teams of `team_of_seat` must be 0..T-1 with no gaps (%d is missing)." % team
			)
			break
	return warnings
