class_name AudioTab
extends VBoxContainer

## Options → Sonido. One AudioBusRow per bus (Master, Music, SFX, Voice, Ambience) and «Silenciar».
## Every control writes the shared AudioPrefs at once; SoundBus listens to `changed` and moves the
## AudioServer buses, so the change is heard live. The controls also follow changes made elsewhere.
## HSlider and CheckButton only: AgentKit drives them with range / click.

## Tab title in the OptionsMenu.
@export var tab_title := "UI_OPTIONS_TAB_AUDIO"
## The shared instance (data/ui/audio_prefs.tres).
@export var prefs: AudioPrefs

var _rows: Array[AudioBusRow] = []


func _ready() -> void:
	if prefs == null:
		push_warning("AudioTab: prefs is missing.")
		return
	for child in get_children():
		if child is AudioBusRow:
			_rows.append(child)
			child.bind(prefs)
	%Mute.toggled.connect(prefs.set_muted)
	prefs.changed.connect(_sync)
	_sync()


func _sync() -> void:
	for row in _rows:
		row.sync()
	%Mute.set_pressed_no_signal(prefs.muted())
