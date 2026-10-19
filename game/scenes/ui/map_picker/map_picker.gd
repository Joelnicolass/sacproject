class_name MapPicker
extends OptionButton

## RFC-049 049a (F290): the picker of the map of a match. It lists the maps a room can offer (`room_selectable` in their
## `MapDefinition`); the test maps only when this process was started with `--room-test-maps`, or, with `offer_test_maps`, in a
## debug build (the boot). It only reads the catalog: the choice goes out through `selected_tag()` (the boot's `MatchSetup`, the
## `world` option of a room) and SacrificeFlow is the one that plays it. The item starts on the map of `--map` when it is listed.

## Offer the test maps too in a debug build (the boot, to try them alone). Rooms never do: they need `--room-test-maps`.
@export var offer_test_maps := false
## Format of an item; `%s` is the display name of the map.
@export var item_text := "UI_MAP_PICKER_ITEM"


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	var catalog := MapCatalog.shared()
	var all := MpBoot.user_flag("room-test-maps") or (offer_test_maps and OS.is_debug_build())
	var active := MapCatalog.current_tag()
	var wanted := 0
	for tag in (catalog.all_tags() if all else catalog.room_tags()):
		var definition := catalog.find(StringName(tag))
		add_item(tr(item_text) % definition.display_name)
		set_item_metadata(item_count - 1, tag)
		if definition.tag == active:
			wanted = item_count - 1
	if item_count > 0:
		select(wanted)


## The tag of the chosen map; empty if the catalog offers none.
func selected_tag() -> StringName:
	if selected < 0:
		return &""
	return StringName(str(get_item_metadata(selected)))
