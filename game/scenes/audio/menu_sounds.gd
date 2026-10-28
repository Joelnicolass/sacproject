@tool
class_name MenuSounds
extends Node

## What the radial X menu sounds like: a cue when it opens, one when an entry is chosen and one when it closes without choosing.
## Each plays on SoundBus's 2D pool when the menu emits its signal (local UI, no RPC); emitter = the menu's name, events
## `menu_open`, `click` and `menu_back`. An empty cue is silence for that moment. With the AudioGate closed it connects
## nothing. Remove the node to silence the whole menu.

@export var menu: RadialMenu:
	set(value):
		menu = value
		update_configuration_warnings()
## The menu opened (`RadialMenu.opened`).
@export var opened: SoundCue
## An entry was chosen (`RadialMenu.entry_chosen`).
@export var chosen: SoundCue
## The menu closed without choosing (`RadialMenu.cancelled`).
@export var cancelled: SoundCue


func _ready() -> void:
	if Engine.is_editor_hint() or menu == null or not AudioGate.is_open():
		return
	menu.opened.connect(play.bind(&"opened"))
	menu.entry_chosen.connect(_on_entry_chosen)
	menu.cancelled.connect(play.bind(&"cancelled"))


## The cue `moment` (`opened`, `chosen` or `cancelled`) plays now, or null when it is empty or silent. The lab asks it to know what to expect.
func cue_for(moment: StringName) -> SoundCue:
	var found: SoundCue = null
	match moment:
		&"opened":
			found = opened
		&"chosen":
			found = chosen
		&"cancelled":
			found = cancelled
	return found if found != null and not found.is_silent() else null


## The SoundEvent the log entry of `moment` carries.
func event_for(moment: StringName) -> StringName:
	match moment:
		&"opened":
			return SoundEvent.MENU_OPEN
		&"cancelled":
			return SoundEvent.MENU_BACK
	return SoundEvent.CLICK


## Plays the cue of `moment`. False when it is silent or SoundBus dropped it.
func play(moment: StringName) -> bool:
	var found := cue_for(moment)
	if found == null or menu == null:
		return false
	return SoundBus.play_2d(found, StringName(menu.name), event_for(moment))


func _on_entry_chosen(_entry: RadialEntry) -> void:
	play(&"chosen")


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if menu != null else PackedStringArray(["Assign in `menu` the menu whose signals make sounds."])
