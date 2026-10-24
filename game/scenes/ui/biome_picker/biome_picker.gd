class_name BiomePicker
extends OptionButton

## The picker of the land of a match: «Aleatoria» (the match draws it from its seed) or the land of one of the gods that bring a look.
## Used by the boot (solo, «Contra la IA»), the room form and the local server form. It only lists: the choice goes out through
## `selected_god()` (the boot's `MatchSetup.biome_god`, the `biome` option of a room); whoever simulates the match applies it.

## Item 0 (metadata ""): the match draws the land.
@export var random_text := "UI_BIOME_RANDOM"
## Format of a god's item; `%s` is the display name of the god.
@export var item_text := "UI_BIOME_ITEM"


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	add_item(tr(random_text))
	set_item_metadata(0, "")
	for type in GameCatalog.shared().gods:
		if not BiomeRules.has_look(StringName(type.tag)):
			continue
		add_item(tr(item_text) % type.display_name)
		set_item_metadata(item_count - 1, type.tag)
	select(0)


## The tag of the chosen god; empty = drawn.
func selected_god() -> StringName:
	if selected < 0:
		return &""
	return StringName(str(get_item_metadata(selected)))
