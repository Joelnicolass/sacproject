class_name AudioBusRow
extends HBoxContainer

## One row of Options → Sonido: the name of a bus, its slider (0..1, linear) and the value in %. The
## AudioTab binds it to the shared AudioPrefs; the row writes the preference at once and follows its
## changes.

## One of AudioPrefs.BUSES.
@export var bus: StringName = &"Master"
## Translation key of the label.
@export var label_key := "UI_AUDIO_TAB_MASTER"
@export var value_format := "%d %%"

var _prefs: AudioPrefs


func _ready() -> void:
	%BusLabel.text = tr(label_key)


func bind(prefs: AudioPrefs) -> void:
	_prefs = prefs
	var slider: HSlider = %Volume
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value_changed.connect(_on_value)
	sync()


## Shows the preference as it is now, without echoing it back.
func sync() -> void:
	if _prefs == null:
		return
	var value := _prefs.volume(bus)
	(%Volume as HSlider).set_value_no_signal(value)
	_show(value)


func _on_value(value: float) -> void:
	_prefs.set_volume(bus, value)
	_show(_prefs.volume(bus))


func _show(value: float) -> void:
	%Value.text = value_format % roundi(value * 100.0)
