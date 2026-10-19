@tool
class_name MenuSounds
extends Node

## RFC-052 052h (F367): a menu's sounds from its own signals (local UI, no RPC). Each signal of `menu` named in `cues` plays
## that key of the `ui_set` set on SoundBus's 2D pool; emitter = the menu's name, event = `events[signal]` (else `click`).
## On the radial X menu (radial_menu.tscn): opened -> XMNU, entry_chosen -> Iclk, cancelled -> Ibak. A signal the menu does
## not have, or a key the set lacks, is silence. With the AudioGate closed it connects nothing. Remove the node to silence it.

@export var menu: Node:
	set(value):
		menu = value
		update_configuration_warnings()
## SoundLibrary path of the set the keys are in.
@export var ui_set := "ui"
## Signal of `menu` -> key in `ui_set`.
@export var cues: Dictionary[StringName, StringName] = {&"opened": &"XMNU", &"entry_chosen": &"Iclk", &"cancelled": &"Ibak"}
## Signal of `menu` -> the SoundEvent of the log entry (a signal not here logs `click`).
@export var events: Dictionary[StringName, StringName] = {&"opened": SoundEvent.MENU_OPEN, &"cancelled": SoundEvent.MENU_BACK}


func _ready() -> void:
	if Engine.is_editor_hint() or menu == null or not AudioGate.is_open():
		return
	for info: Dictionary in menu.get_signal_list():
		var signal_name := StringName(info.name)
		if cues.has(signal_name):
			var argc := (info.args as Array).size()
			var call := play.bind(signal_name)
			menu.connect(signal_name, call.unbind(argc) if argc > 0 else call)


## The cue `signal_name` plays now, or null. The lab asks it to know what to expect.
func cue_for(signal_name: StringName) -> SoundCue:
	return SoundBus.lookup(ui_set, cues[signal_name]) if cues.has(signal_name) else null


## Plays the cue of `signal_name`. False when it is silent or SoundBus dropped it.
func play(signal_name: StringName) -> bool:
	var cue := cue_for(signal_name)
	if cue == null or menu == null:
		return false
	return SoundBus.play_2d(cue, StringName(menu.name), events.get(signal_name, SoundEvent.CLICK))


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if menu != null else PackedStringArray(["Asigná en `menu` el menú cuyas señales suenan."])
