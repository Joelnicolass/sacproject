class_name MapPicker
extends OptionButton

## RFC-049 049a (F290): the picker of the map of a match. It lists the maps a room can offer (`room_selectable` in their
## `MapDefinition`); the test maps only when this process was started with `--room-test-maps`, or, with `offer_test_maps`, in a
## debug build (the boot). It only reads the catalog: the choice goes out through `selected_tag()` (the boot's `MatchSetup`, the
## `world` option of a room) and SacrificeFlow is the one that plays it. The item starts on the map of `--map` when it is listed.
## RFC-049 049h (F297): with a ModePicker in `mode_picker`, it lists only the maps with a start for each seat of the chosen mode,
## and fills again when the mode changes (keeping the chosen map if it still fits).

## Offer the test maps too in a debug build (the boot, to try them alone). Rooms never do: they need `--room-test-maps`.
@export var offer_test_maps := false
## Format of an item; `%s` is the display name of the map.
@export var item_text := "UI_MAP_PICKER_ITEM"
## Optional: the mode picker of the same screen. Empty = every offered map.
@export var mode_picker: ModePicker


func _ready() -> void:
	if mode_picker != null:
		if mode_picker.item_count == 0:
			mode_picker.fill()
		mode_picker.item_selected.connect(_on_mode_selected)
	fill()


## The tags a screen offers: the room maps, plus the test maps with `--room-test-maps` or (`with_test_maps`) in a debug build.
static func offered_tags(with_test_maps: bool) -> PackedStringArray:
	var catalog := MapCatalog.shared()
	var all := MpBoot.user_flag("room-test-maps") or (with_test_maps and OS.is_debug_build())
	return catalog.all_tags() if all else catalog.room_tags()


func fill() -> void:
	var keep := selected_tag()
	clear()
	var catalog := MapCatalog.shared()
	var mode: GameMode = null
	if mode_picker != null and mode_picker.selected_tag() != &"":
		mode = GameModeCatalog.shared().find(mode_picker.selected_tag())
	var active := MapCatalog.current_tag()
	var wanted := 0
	var kept := -1
	for tag in offered_tags(offer_test_maps):
		var definition := catalog.find(StringName(tag))
		if mode != null and not definition.fits(mode):
			continue
		add_item(tr(item_text) % definition.display_name)
		set_item_metadata(item_count - 1, tag)
		if definition.tag == active:
			wanted = item_count - 1
		if definition.tag == keep:
			kept = item_count - 1
	if item_count > 0:
		select(kept if kept >= 0 else wanted)


## The tag of the chosen map; empty if the catalog offers none.
func selected_tag() -> StringName:
	if selected < 0:
		return &""
	return StringName(str(get_item_metadata(selected)))


func _on_mode_selected(_index: int) -> void:
	fill()
