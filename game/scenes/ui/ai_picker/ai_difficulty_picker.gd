class_name AiDifficultyPicker
extends OptionButton

## How well an AI plays (AiSeat.difficulty_ids(): easy, normal, hard). With `offer_human`, item 0 is
## «a person» (metadata ""): the local server uses it for each seat (a person with a code, or an AI
## of this difficulty). It only lists: the choice goes out through `selected_difficulty()` and
## `is_human()`.

## Item 0 is a person instead of an AI.
@export var offer_human := false
@export var human_text := "UI_AI_SEAT_HUMAN"
## Format of an AI item; `%s` is the translated name of the difficulty.
@export var item_text := "UI_AI_DIFFICULTY_ITEM"
## The item selected at start (an id of AiSeat.difficulty_ids()); with `offer_human` the person is
## selected at start.
@export var initial_difficulty := "normal"

const NAMES := {
	"easy": "UI_AI_DIFFICULTY_EASY",
	"normal": "UI_AI_DIFFICULTY_NORMAL",
	"hard": "UI_AI_DIFFICULTY_HARD"
}


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	var wanted := 0
	if offer_human:
		add_item(tr(human_text))
		set_item_metadata(0, "")
	for tag in AiSeat.difficulty_ids():
		add_item(tr(item_text) % tr(NAMES.get(tag, tag)))
		set_item_metadata(item_count - 1, tag)
		if tag == initial_difficulty and not offer_human:
			wanted = item_count - 1
	select(wanted)


## The tag of the chosen difficulty; empty when the item is a person.
func selected_difficulty() -> String:
	if selected < 0:
		return ""
	return str(get_item_metadata(selected))


func is_human() -> bool:
	return selected_difficulty().is_empty()


## The translated name of a difficulty tag (LobbyText and the seat rows show it).
static func difficulty_name(tag: String) -> String:
	return UiText.t(NAMES.get(tag, NAMES["normal"]))
