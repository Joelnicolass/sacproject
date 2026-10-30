extends Control

## Creates an online room. The host's pick comes from the menu (`SacrificeFlow.pick`); here he
## chooses the mode, the map, the land, the room's name and whether it shows in the list. «Crear»
## asks SacrificeFlow for the room (the seats are those of the mode, all of them people); when it is
## up the view shows the code friends type. The host joins his own match by himself: the world
## starts when every seat is in. Not: the ticket (OnlineTicket), the room's life (MpOnline).

signal back_requested

var _online: MpOnline

@onready var _form: Control = %HostForm
@onready var _info: Control = %RoomInfo


func _ready() -> void:
	%CreateRoom.pressed.connect(_on_create)
	%CopyCode.pressed.connect(_on_copy)
	%HostBack.pressed.connect(_on_back)
	_show_form()


func _show_form() -> void:
	_form.visible = true
	_info.visible = false


func _on_create() -> void:
	if _online != null:
		return
	# The mode, the map and the land go in the ticket like a room's options.
	var chosen := MatchSetup.new()
	chosen.mode = (%HostMode as ModePicker).selected_mode()
	chosen.map = (%HostMap as MapPicker).selected_map()
	chosen.biome = (%HostBiome as BiomePicker).selected_god()
	chosen.sky_hour = (%HostHour as HourPicker).selected_hour()
	chosen.weather = (%HostWeather as WeatherPicker).selected_weather()
	chosen.forest = -1 if (%HostForest as CheckBox).button_pressed else 0
	var room := (%RoomName as LineEdit).text.strip_edges()
	_online = SacrificeFlow.host_online_room(
		MatchWire.options_of(chosen), room, (%Listed as CheckBox).button_pressed
	)
	if _online == null:
		return
	_online.room_ready.connect(_on_room_ready)
	_online.failed.connect(_on_closed.unbind(1))
	_online.ended.connect(_on_closed)
	_form.visible = false


func _on_room_ready(code: String) -> void:
	%RoomCode.text = tr("UI_ONLINE_ROOM_CODE") % code
	_info.visible = true


## The issuer refused, the match could not start, or the room closed: the form again (the status
## line says why).
func _on_closed() -> void:
	_online = null
	_show_form()


func _on_copy() -> void:
	if _online != null and not _online.code.is_empty():
		DisplayServer.clipboard_set(_online.code)


func _on_back() -> void:
	if _online != null:
		var closing := _online
		_online = null
		closing.stop()
	_show_form()
	back_requested.emit()
