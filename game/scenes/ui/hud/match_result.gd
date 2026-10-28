@tool
class_name MatchResult
extends Label

## The result of the match for the player of this process: «Victoria», «Derrota» or «Fin de partida».
## Hidden while the match goes on and on the dedicated server (it has no player).
## «Victoria» when the team of the player won (`MatchState.won`); with a team of two or more, `team_label` adds
## «Ganó el equipo de A y B» with the wizards of the winning team.

@export var match_state: MatchState
## Who looks at this screen: the banner tells this seat's result.
@export var seat: MpLocalSeat
@export var victory_text := "UI_RESULT_VICTORY"
@export var defeat_text := "UI_RESULT_DEFEAT"
@export var draw_text := "UI_RESULT_DRAW"
## Optional line under the banner for a team result (a child Label in match_result.tscn).
@export var team_label: Label
## `%s` is the list of names of the winning team.
@export var team_text := "UI_RESULT_TEAM"
## Name of a slot whose wizard is not known; `%d` is the slot.
@export var slot_text := "UI_RESULT_SLOT"
## Word between the last two names.
@export var and_text := "UI_RESULT_AND"


func _ready() -> void:
	visible = false
	if Engine.is_editor_hint() or match_state == null or seat == null:
		return
	match_state.result_changed.connect(_refresh)
	seat.changed.connect(_on_seat_changed)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if match_state == null:
		warnings.append("Assign in `match_state` the MatchState.")
	if seat == null:
		warnings.append("Assign in `seat` the MpLocalSeat.")
	return warnings


## What the banner says for `slot`; empty with no result or no player.
func text_for(slot: int) -> String:
	if match_state == null or not match_state.has_result() or slot <= 0:
		return ""
	if slot == match_state.winner_slot or match_state.won(slot):
		return tr(victory_text)
	if match_state.is_defeated(slot):
		return tr(defeat_text)
	return tr(draw_text)


## The team line for `slot`: empty with no result, no player, or a winner alone (1v1, all against all).
func team_text_for(slot: int) -> String:
	if (
		match_state == null
		or not match_state.has_result()
		or slot <= 0
		or match_state.winner_slots.size() < 2
	):
		return ""
	var names := PackedStringArray()
	for winner in match_state.winner_slots:
		names.append(_name_of(winner))
	var last := names[names.size() - 1]
	names.resize(names.size() - 1)
	return tr(team_text) % ("%s %s %s" % [", ".join(names), tr(and_text), last])


func _name_of(slot: int) -> String:
	var chosen: WizardPick = SacrificeFlow.pick_for(slot)
	return chosen.wizard.display_name if chosen != null else tr(slot_text) % slot


func _refresh() -> void:
	var slot := seat.slot
	text = text_for(slot)
	visible = not text.is_empty()
	if team_label != null:
		team_label.text = team_text_for(slot)
		team_label.visible = not team_label.text.is_empty()


func _on_seat_changed(_slot: int) -> void:
	_refresh()
