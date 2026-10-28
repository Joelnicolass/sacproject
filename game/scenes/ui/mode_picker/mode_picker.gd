class_name ModePicker
extends OptionButton

## The picker of the game mode of a match (1v1, 2v2, all against all). It lists the modes rooms
## offer (`room_selectable` in their `GameMode`) that have at least one map the same screen offers
## (MapPicker.offers), so a mode is never offered without a map for its seats. The metadata of each
## item is the GameMode itself and `selected_mode()` hands it over. It starts on the mode
## `ActiveMatch` plays (the one of `--mode`) when listed. A MapPicker with this node in its
## `mode_picker` socket lists only the maps that fit the chosen mode.

## Count the test maps too (same meaning as MapPicker.offer_test_maps; set both the same in a
## screen).
@export var offer_test_maps := false
## Format of an item; `%s` is the translated display name of the mode.
@export var item_text := "UI_MODE_PICKER_ITEM"


func _ready() -> void:
	if item_count == 0:
		fill()


func fill() -> void:
	clear()
	var maps := GameCatalog.shared().maps()
	var active := SacrificeFlow.active_match.mode()
	var wanted := 0
	for mode in GameCatalog.shared().modes:
		if not mode.room_selectable or not _has_map(mode, maps):
			continue
		add_item(tr(item_text) % tr(mode.display_name))
		set_item_metadata(item_count - 1, mode)
		if mode.tag == active.tag:
			wanted = item_count - 1
	if item_count > 0:
		select(wanted)


## The chosen mode; null if the catalog offers none.
func selected_mode() -> GameMode:
	return get_item_metadata(selected) as GameMode if selected >= 0 else null


func _has_map(mode: GameMode, maps: Array[MapDefinition]) -> bool:
	for definition in maps:
		if MapPicker.offers(definition, offer_test_maps) and definition.fits(mode):
			return true
	return false
