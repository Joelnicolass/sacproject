extends Control

## The form that creates a room: name, private or open, the mode, the map, the land and the level of both wizards. It calls `MpLobby.client.create_room`; the screen moves to the room
## when the server answers. Run alone (F6) it says «Sin conexión».

signal cancelled

const LEVEL_MIN := 1
const LEVEL_MAX := 9
## Item 0 of the level picker: no `level` option, the rules decide.
const LEVEL_RULES_TEXT := "UI_ROOM_CREATE_LEVEL_RULES"

@export var name_max_len: int = 24


func _ready() -> void:
	%RoomName.max_length = name_max_len
	_fill_levels()
	%CreateConfirm.pressed.connect(_on_create)
	%RoomName.text_submitted.connect(_on_name_submitted)
	%CreateCancel.pressed.connect(cancelled.emit)
	MpLobby.client.lobby_lost.connect(_on_lost)
	_refresh()


func _fill_levels() -> void:
	var picker: OptionButton = %RoomLevel
	picker.clear()
	picker.add_item(tr(LEVEL_RULES_TEXT))
	picker.set_item_metadata(0, 0)
	for level in range(LEVEL_MIN, LEVEL_MAX + 1):
		picker.add_item(tr("UI_ROOM_CREATE_LEVEL") % level)
		picker.set_item_metadata(picker.item_count - 1, level)
	picker.select(0)


func _refresh() -> void:
	var online := MpLobby.client.is_online()
	%CreateConfirm.disabled = not online
	%CreateStatus.text = "" if online else tr(LobbyText.OFFLINE)


func _on_lost(_reason: String) -> void:
	_refresh()


## The options Dictionary of the room: the `mode` of %RoomMode, the `world` of %RoomMap, the `biome` of %RoomBiome (empty = drawn) and, if chosen, the
## `level` (0 = the rules decide).
func options() -> Dictionary:
	var picker: OptionButton = %RoomLevel
	var chosen := MatchSetup.new()
	chosen.level = int(picker.get_item_metadata(picker.selected))
	chosen.mode = (%RoomMode as ModePicker).selected_mode()
	chosen.map = (%RoomMap as MapPicker).selected_map()
	chosen.biome = (%RoomBiome as BiomePicker).selected_god()
	return MatchWire.options_of(chosen)


func _on_create() -> void:
	var room_name: String = %RoomName.text.strip_edges()
	var is_private: bool = %RoomPrivate.button_pressed
	MpLobby.client.create_room(room_name, is_private, options())


func _on_name_submitted(_text: String) -> void:
	_on_create()
