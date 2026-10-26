class_name AiSeat
extends Resource

## A seat the AI takes: which slot, which wizard and god, how well it plays. Drag the wizard and the god from the FileSystem
## (data/catalog/wizards, data/gods). It does not play: AiRoster (or the bench) seats it and AiSide plays it.

@export var slot := 2
## Empty = the wizard of the menu's default pick (`SacrificeFlow.default_pick`).
@export var wizard: WizardType
## Empty: AiRoster draws one per match from the gods the lobby offers («Aleatorio»).
@export var god: GodType
## How well it plays (024e). Empty: Normal (data/ai/difficulty_normal.tres).
@export var difficulty: AiDifficulty
## A personality of its own: these tactics instead of the difficulty's. Empty: the difficulty's (AiDifficulty.tactics).
@export var tactics: AiTactics
## The wizard's book instead of his god's (a bench or a solo game: it does not travel on the network). Empty: the god's.
@export var book: GodBook
## The seats of a debug scene start paused: the runner starts them (AiSide.active).
@export var start_active := true
## The scene of the AI side of this seat; empty = the default of the bench (ai_side.tscn). The bench opponent of 024d is
## debug/ai/ai_side_trivial.tscn (summons and stays at its altar).
@export var side_scene: PackedScene


## The difficulty with that id (a room's or a screen's: easy, normal, hard; data/ai/difficulties.tres); null for an empty or
## unknown id (the seat then plays Normal).
static func difficulty_of(id: String) -> AiDifficulty:
	return AiDifficultyList.shared().find(id)


## The ids a room or a screen may name, in the order of the menus.
static func difficulty_ids() -> PackedStringArray:
	return AiDifficultyList.shared().ids()


## The difficulty of the seat, Normal when it has none.
func difficulty_or_normal() -> AiDifficulty:
	return difficulty if difficulty != null else difficulty_of("normal")


## A copy of this seat for `p_slot`, with `p_god` when given (null keeps the seat's own god; none = drawn when the match starts).
func for_slot(p_slot: int, p_god: GodType = null) -> AiSeat:
	var seat := duplicate() as AiSeat
	seat.slot = p_slot
	if p_god != null:
		seat.god = p_god
	return seat


## A copy of this seat for each slot from 2 to `seats` (slot 1 is the player's), all with `p_god` when given.
func for_seats(seats: int, p_god: GodType = null) -> Array[AiSeat]:
	var found: Array[AiSeat] = []
	for slot in range(2, maxi(seats, 2) + 1):
		found.append(for_slot(slot, p_god))
	return found
