class_name MpLeaveButton
extends Button

## Drop one in a HUD: it leaves the match (back to the lobby for an online match, to the boot menu otherwise).
## Solo, host or client, the same button. Not: ending the match for everyone (MpMatch.finish).


func _ready() -> void:
	if text.is_empty():
		text = "Leave"
	pressed.connect(_leave)


func _leave() -> void:
	var flow := MpFlow.find_in_tree(self)
	if flow:
		flow.leave_match()
