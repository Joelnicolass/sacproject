class_name GroupKeys
extends Node

## The keys 1..9, 0 of the selection groups: `group_set_N` (Ctrl+N) stores the selection, `group_N`
## selects the group and Shift+`group_N` adds it to the selection. The groups themselves belong to
## Selection; this node only reads the keys.

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

@onready var _selection: RtsSelection = %Selection


## True when `event` was one of the group keys (and is used up).
func handle(event: InputEvent) -> bool:
	for i in KEYS.size():
		if event.is_action_pressed("group_set_%s" % KEYS[i], false, true):
			_selection.define_group(i)
			return true
		if event.is_action_pressed("group_%s" % KEYS[i]):
			if event is InputEventKey and (event as InputEventKey).shift_pressed:
				_selection.extend_group(i)
			else:
				_selection.select_group(i)
			return true
	return false
