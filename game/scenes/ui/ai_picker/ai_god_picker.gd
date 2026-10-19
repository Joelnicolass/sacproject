class_name AiGodPicker
extends OptionButton

## RFC-049 049h (F297): the god an AI plays with: «Aleatorio» (drawn when the match starts) or one of the gods of the game. Used by the
## boot («Contra la IA») and by the host of a room when he adds a bot. It only lists: the choice goes out through `selected_god()`.

## Item 0 (metadata ""): the AI draws its god.
@export var random_text := "UI_AI_GOD_RANDOM"
## Format of a god's item; `%s` is the display name of the god.
@export var item_text := "UI_AI_GOD_ITEM"


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	add_item(tr(random_text))
	set_item_metadata(0, "")
	for god in GameData.gods():
		add_item(tr(item_text) % GameData.god(god).display_name)
		set_item_metadata(item_count - 1, god)
	select(0)


## The tag of the chosen god; empty = drawn.
func selected_god() -> StringName:
	if selected < 0:
		return &""
	return StringName(str(get_item_metadata(selected)))
