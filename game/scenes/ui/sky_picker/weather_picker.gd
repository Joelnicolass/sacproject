class_name WeatherPicker
extends OptionButton

## The picker of the weather of a match: «Automático» (the land's weather plan) or one weather all
## match long. Next to BiomePicker in the boot, the room form and the host forms. The metadata of
## each item is the WeatherState; the choice goes out through `selected_weather()` (null = the
## plan) and MatchSky forces it on every peer.

## Item 0: the land's weather plan.
@export var auto_text := "UI_WEATHER_AUTO"
## Format of a weather's item; `%s` is its display name.
@export var item_text := "UI_WEATHER_ITEM"
## The weathers offered (files of MatchWire.WEATHER_DIR, so they travel by name).
@export var weathers: Array[WeatherState] = []


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	add_item(tr(auto_text))
	for weather in weathers:
		if weather == null:
			continue
		add_item(tr(item_text) % weather.display_name)
		set_item_metadata(item_count - 1, weather)
	select(0)


## The weather chosen; null = the land's plan.
func selected_weather() -> WeatherState:
	return get_item_metadata(selected) as WeatherState if selected >= 0 else null
