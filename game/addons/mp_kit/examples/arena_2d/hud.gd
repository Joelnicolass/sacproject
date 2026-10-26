extends CanvasLayer

## Shows who you are and the score (the Leave button next to it is an MpLeaveButton). Reads MpState; writes nothing.

@export var state: MpState


func _ready() -> void:
	state.changed.connect(_refresh.unbind(2))
	MpKit.slot_assigned.connect(_refresh.unbind(1))
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray([_role()])
	var keys := state.values.keys()
	keys.sort()
	for key in keys:
		lines.append("%s: %s" % [String(key).to_upper(), state.values[key]])
	%Info.text = "\n".join(lines)


func _role() -> String:
	if not MpKit.is_networked():
		return "Solo"
	if MpKit.is_dedicated():
		return "Dedicated server"
	if MpKit.is_server():
		return "Host · P%d" % MpKit.local_slot()
	return "Client · P%d" % MpKit.local_slot()
