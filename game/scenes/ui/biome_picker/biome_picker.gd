class_name BiomePicker
extends OptionButton

## The picker of the land of a match: «Aleatoria» (the match draws it from its seed) or the land of
## one of the gods that bring a look. Used by the boot (solo, «Contra la IA»), the room form and the
## local server form. It only lists: the metadata of each item is the GodType and the choice goes
## out through `selected_god()` (null = drawn); whoever simulates the match applies it.

## Item 0 (metadata ""): the match draws the land.
@export var random_text := "UI_BIOME_RANDOM"
## Format of a god's item; `%s` is the display name of the god.
@export var item_text := "UI_BIOME_ITEM"


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	add_item(tr(random_text))
	for type in GameCatalog.shared().offered_gods():
		if type.look == null:
			continue
		add_item(tr(item_text) % type.display_name)
		set_item_metadata(item_count - 1, type)
	select(0)


## The god whose land was chosen; null = drawn.
func selected_god() -> GodType:
	return get_item_metadata(selected) as GodType if selected >= 0 else null
