@tool
class_name LobbyReturn
extends VBoxContainer

## «Volver a salas», under the result banner of a match that came from a room. It shows when the match
## ends (the world's `MatchState` has a result, or the dedicated reports the end: an abandon has no banner) and only
## in a match from a room. The line above the button tells an abandon or a closed match; a normal result is already
## in the banner. The button asks the session flow to leave; the flow lands in the room screens.
## Ref: RFC-034 034f.

@export var match_state: MatchState

var _reported: Dictionary = {}


func _ready() -> void:
	visible = false
	if Engine.is_editor_hint():
		return
	%LobbyReturnButton.pressed.connect(_on_return)
	MpKit.session_ended.connect(_on_session_ended)
	if match_state != null:
		match_state.result_changed.connect(_refresh)
	_refresh()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if match_state == null:
		warnings.append("Asigná en `match_state` el MatchState.")
	return warnings


func _on_session_ended(data: Dictionary) -> void:
	_reported = data
	_refresh()


func _refresh() -> void:
	var ended := not _reported.is_empty() or (match_state != null and match_state.has_result())
	visible = SacrificeFlow.from_lobby and ended
	var note := ""
	if str(_reported.get("reason", "result")) != "result":
		note = LobbyText.result_text(_reported, MpKit.local_slot())
	%LobbyResult.text = note
	%LobbyResult.visible = not note.is_empty()


func _on_return() -> void:
	var flow := MpFlow.find_in_tree(self)
	if flow == null:
		push_warning("LobbyReturn: no hay MpFlow para volver a las salas")
		return
	flow.return_to_boot()
