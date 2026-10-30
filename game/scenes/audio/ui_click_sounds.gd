class_name UiClickSounds
extends Node

## The click of every button: each BaseButton that enters the tree plays `click` when it is pressed,
## on SoundBus's 2D pool (emitter = the button's name, event `click`). It does not decide what a
## button does, only what pressing it sounds like.
## - A button with the data `ui_sound` (a SoundCue, set in its scene: the spell book's slots) plays
##   that cue instead.
## - A button with the data `no_ui_sound` (any value but false) plays nothing. Both are read on
##   press.
## - With the AudioGate closed (dedicated server, room server, headless run) it connects to nothing.

const META_NO_UI_SOUND := &"no_ui_sound"
const META_UI_SOUND := &"ui_sound"

## What a plain button press sounds like (empty = plain buttons are silent).
@export var click: SoundCue


func _ready() -> void:
	if not AudioGate.is_open():
		return
	get_tree().node_added.connect(_on_node_added)
	# The main scene entered the tree with the autoloads, before this _ready: its buttons are
	# already there.
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)


## The cue a press of `button` plays now, or null (gate closed, `no_ui_sound`, no cue, silent). The
## lab asks it to know what to expect.
func cue_for(button: BaseButton) -> SoundCue:
	if not AudioGate.is_open() or button == null:
		return null
	if button.has_meta(META_NO_UI_SOUND) and button.get_meta(META_NO_UI_SOUND) != false:
		return null
	var own: Variant = button.get_meta(META_UI_SOUND, click)
	var found: SoundCue = own if own is SoundCue else null
	return found if found != null and not found.is_silent() else null


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	var on_press := _on_pressed.bind(button)
	if not button.pressed.is_connected(on_press):
		button.pressed.connect(on_press)


func _on_pressed(button: BaseButton) -> void:
	var found := cue_for(button) if is_instance_valid(button) else null
	if found != null:
		SoundBus.play_2d(found, StringName(button.name), SoundEvent.CLICK)
