class_name ModePicker
extends OptionButton

## RFC-049 049h (F297): the picker of the game mode of a match (1v1, 2v2, all against all). It lists the modes rooms offer
## (`room_selectable` in their `GameMode`) that have at least one map the same screen offers (MapPicker.offered_tags), so a mode
## is never offered without a map for its seats. It only reads the catalogs: the choice goes out through `selected_tag()` (the boot's
## `MatchSetup.mode_tag`, the `mode` option of a room, the local server's ticket). The item starts on the mode of `--mode` when listed.
## A MapPicker with this node in its `mode_picker` socket lists only the maps that fit the chosen mode.

## Count the test maps too (same meaning as MapPicker.offer_test_maps; set both the same in a screen).
@export var offer_test_maps := false
## Format of an item; `%s` is the translated display name of the mode.
@export var item_text := "UI_MODE_PICKER_ITEM"


func _ready() -> void:
	if item_count == 0:
		fill()


func fill() -> void:
	clear()
	var modes := GameModeCatalog.shared()
	var maps := MapCatalog.shared()
	var offered := MapPicker.offered_tags(offer_test_maps)
	var active := GameModeCatalog.current_tag()
	var wanted := 0
	for tag in modes.room_tags():
		var mode := modes.find(StringName(tag))
		if not _has_map(mode, maps, offered):
			continue
		add_item(tr(item_text) % tr(mode.display_name))
		set_item_metadata(item_count - 1, tag)
		if mode.tag == active:
			wanted = item_count - 1
	if item_count > 0:
		select(wanted)


## The tag of the chosen mode; empty if the catalog offers none.
func selected_tag() -> StringName:
	if selected < 0:
		return &""
	return StringName(str(get_item_metadata(selected)))


func _has_map(mode: GameMode, maps: MapCatalog, offered: PackedStringArray) -> bool:
	for tag in offered:
		var definition := maps.find(StringName(tag))
		if definition != null and definition.fits(mode):
			return true
	return false
