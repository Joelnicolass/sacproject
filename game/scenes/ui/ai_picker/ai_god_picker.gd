class_name AiGodPicker
extends OptionButton

## The god an AI plays with: «Aleatorio» (drawn when the match starts) or one of the gods of the game. Used by the
## boot («Contra la IA») and by the host of a room when he adds a bot. It only lists: the choice goes out through `selected_god()`.
## Ref: RFC-049 049h (F297).

## Item 0 (no god): the AI draws its god.
@export var random_text := "UI_AI_GOD_RANDOM"
## Format of a god's item; `%s` is the display name of the god.
@export var item_text := "UI_AI_GOD_ITEM"


func _ready() -> void:
	fill()


## Lists «Aleatorio» and the gods the lobby offers (`GodType.offered`); the metadata of an item is its GodType.
func fill() -> void:
	clear()
	add_item(tr(random_text))
	set_item_metadata(0, null)
	for god in GameCatalog.shared().offered_gods():
		add_item(tr(item_text) % god.display_name)
		set_item_metadata(item_count - 1, god)
	select(0)


## The chosen god; null = drawn.
func selected_god() -> GodType:
	if selected < 0:
		return null
	return get_item_metadata(selected) as GodType
