class_name MapPicker
extends OptionButton

## The picker of the map of a match. It lists the maps a room can offer (`room_selectable` in their `MapDefinition`); the test maps
## only when this process was started with `--room-test-maps`, or, with `offer_test_maps`, in a debug build (the boot). The metadata of
## each item is the MapDefinition itself, so `selected_map()` hands it over and the screens never read a tag. It starts on the map
## `ActiveMatch` plays (the one of `--map`) when it is listed.
## With a ModePicker in `mode_picker`, it lists only the maps with a start for each seat of the chosen mode, and fills again when
## the mode changes (keeping the chosen map if it still fits).

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


## True when a screen lists `definition`: a room map, or any playable one with `--room-test-maps` or (`with_test_maps`) in a debug build.
static func offers(definition: MapDefinition, with_test_maps: bool) -> bool:
	var all := MpBoot.user_flag("room-test-maps") or (with_test_maps and OS.is_debug_build())
	return definition.playable and (definition.room_selectable or all)


func fill() -> void:
	var keep := selected_map()
	clear()
	var mode: GameMode = mode_picker.selected_mode() if mode_picker != null else null
	var active := SacrificeFlow.active_match.map()
	var wanted := 0
	var kept := -1
	for definition in GameCatalog.shared().maps():
		if not offers(definition, offer_test_maps) or (mode != null and not definition.fits(mode)):
			continue
		add_item(tr(item_text) % definition.display_name)
		set_item_metadata(item_count - 1, definition)
		if definition.tag == active.tag:
			wanted = item_count - 1
		if keep != null and definition.tag == keep.tag:
			kept = item_count - 1
	if item_count > 0:
		select(kept if kept >= 0 else wanted)


## The chosen map; null if the catalog offers none.
func selected_map() -> MapDefinition:
	return get_item_metadata(selected) as MapDefinition if selected >= 0 else null


func _on_mode_selected(_index: int) -> void:
	fill()
