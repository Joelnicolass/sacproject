class_name RtsGroupKeys
extends Node

## The keys of the selection groups: `rts_group_set_N` (Ctrl+N, Cmd+N on macOS) stores the selection,
## `rts_group_N` selects the group and Shift+`rts_group_N` adds the selection to it. N runs 1..9 and
## 0 (group indexes 0..9). The groups belong to RtsSelection; this node only reads the keys. A key
## with Alt held is never a group key (Alt+N keeps a formation, RtsCommandInput), whatever node sees
## it first.

const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

@export var selection: RtsSelection
@export var action_prefix := "rts_group_"
@export var set_action_prefix := "rts_group_set_"


## True when `event` was one of the group keys (and was used).
func handle(event: InputEvent) -> bool:
	if selection == null:
		return false
	if event is InputEventWithModifiers and (event as InputEventWithModifiers).alt_pressed:
		return false
	for i in mini(KEYS.size(), selection.group_count):
		var set_action := StringName(set_action_prefix + KEYS[i])
		if InputMap.has_action(set_action) and event.is_action_pressed(set_action, false, true):
			selection.define_group(i)
			return true
		var action := StringName(action_prefix + KEYS[i])
		if InputMap.has_action(action) and event.is_action_pressed(action):
			if event is InputEventWithModifiers and (event as InputEventWithModifiers).shift_pressed:
				selection.extend_group(i)
			else:
				selection.select_group(i)
			return true
	return false
