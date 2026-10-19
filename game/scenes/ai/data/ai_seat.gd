class_name AiSeat
extends Resource

## A seat the AI takes (RFC-024 §3.1 `AiSeat`): which slot, which wizard and god, which numbers. 024c only reads it in
## the debug scenes (the production roster, the button and the difficulties come with 024f); the fields are the ones
## the roster will need.

@export var slot := 2
## WizardType tag (cwa0…); empty = the default of SacrificeFlow.
@export var wizard := "cwa0"
## persephone, pyro, james, stratos, charnel. Empty (or unknown): AiRoster draws one per match («Aleatorio», 024f).
@export var god: StringName = &"james"
## Empty: the profile of the god (AiProfile.for_god).
@export var profile: AiProfile
## How well it plays (024e). Empty: Normal (data/ai/difficulty_normal.tres).
@export var difficulty: AiDifficulty
## The seats of a debug scene start paused: the runner starts them (AiSide.active).
@export var start_active := true
## The scene of the AI side of this seat; empty = the default of the bench (ai_side.tscn). The bench opponent of 024d is
## debug/ai/ai_side_trivial.tscn (summons and stays at its altar).
@export var side_scene: PackedScene


const NORMAL := "res://data/ai/difficulty_normal.tres"
## RFC-049 049h (F297): the difficulties a room or a screen names by tag (`difficulty` of a bot seat); each is data/ai/difficulty_<tag>.tres.
const DIFFICULTY_TAGS: PackedStringArray = ["easy", "normal", "hard"]
const DIFFICULTY_PATH := "res://data/ai/difficulty_%s.tres"


## The difficulty with that tag; null for an empty or unknown tag (the seat then plays Normal).
static func difficulty_of(tag: String) -> AiDifficulty:
	if not DIFFICULTY_TAGS.has(tag):
		return null
	return load(DIFFICULTY_PATH % tag) as AiDifficulty


## The difficulty of the seat, Normal when it has none.
func difficulty_or_normal() -> AiDifficulty:
	return difficulty if difficulty != null else load(NORMAL) as AiDifficulty
