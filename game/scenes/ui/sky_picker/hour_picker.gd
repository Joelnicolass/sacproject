class_name HourPicker
extends OptionButton

## The picker of the hour of a match: «Automática» (the land's own clock) or an hour that stays
## all match long. Next to BiomePicker in the boot, the room form and the host forms. It only
## lists: the choice goes out through `selected_hour()` (-1 = the land's clock) and MatchSky pins it
## on every peer.

## Item 0: the land's own clock.
@export var auto_text := "UI_HOUR_AUTO"
## The hours offered (0..24) and their names, in the same order.
@export var hours: PackedFloat32Array = [11.0, 16.75, 0.0]
@export var hour_texts: PackedStringArray = ["UI_HOUR_DAY", "UI_HOUR_DUSK", "UI_HOUR_NIGHT"]


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	add_item(tr(auto_text))
	set_item_metadata(0, -1.0)
	for i in mini(hours.size(), hour_texts.size()):
		add_item(tr(hour_texts[i]))
		set_item_metadata(item_count - 1, hours[i])
	select(0)


## The hour chosen, 0..24; -1 = the land's clock.
func selected_hour() -> float:
	return float(get_item_metadata(selected)) if selected >= 0 else -1.0
