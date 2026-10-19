@tool
class_name MatchResultBanner
extends Label

## The result of the match for the player of this process: «Victoria», «Derrota» or «Fin de partida».
## Hidden while the match goes on and on the dedicated server (it has no player).

@export var match_state: MatchState
@export var victory_text := "Victoria"
@export var defeat_text := "Derrota"
@export var draw_text := "Fin de partida"


func _ready() -> void:
	visible = false
	if Engine.is_editor_hint() or match_state == null:
		return
	match_state.result_changed.connect(_refresh)
	MpKit.slot_assigned.connect(_on_slot_assigned)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if match_state == null:
		warnings.append("Asigná en `match_state` el MatchState.")
	return warnings


## What the banner says for `slot`; empty with no result or no player.
func text_for(slot: int) -> String:
	if match_state == null or not match_state.has_result() or slot <= 0:
		return ""
	if slot == match_state.winner_slot:
		return victory_text
	if match_state.is_defeated(slot):
		return defeat_text
	return draw_text


func _refresh() -> void:
	text = text_for(MpKit.local_slot())
	visible = not text.is_empty()


func _on_slot_assigned(_slot: int) -> void:
	_refresh()
