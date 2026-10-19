class_name LocalSeatRow
extends HBoxContainer

## RFC-049 049h (F297): one seat of a «Servidor local» besides the host's: a person (who gets a code) or an AI of a difficulty
## (%SeatChoice). The view builds one per seat of the mode and reads `ai_meta()` when the server starts.

## Text of the seat; `%d` the seat, `%d` the team (from 1).
@export var label_text := "UI_LOCAL_SEAT_LABEL"

var slot := 0

@onready var _choice: AiDifficultyPicker = %SeatChoice


func show_slot(p_slot: int, team: int) -> void:
	slot = p_slot
	%SeatLabel.text = tr(label_text) % [p_slot, team + 1]


## The meta of the AI that plays this seat ({god, difficulty}; the god is drawn); empty when a person sits here.
func ai_meta() -> Dictionary:
	if _choice.is_human():
		return {}
	return {"god": "", "difficulty": _choice.selected_difficulty()}
