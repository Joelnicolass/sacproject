extends Control

## RFC-034 034f: the first view of the room screens: the player's name and «Conectar». Only debug builds show a field
## for the server (the others use data/net/lobby_endpoint.tres). It does not connect by itself: it asks.

signal connect_requested(display_name: String, host_override: String)
signal back_requested

const NAME_PREFIX := "Jugador"
const NAME_SUFFIX_RANGE := 1000

@export var name_max_len: int = 24


func _ready() -> void:
	%PlayerName.max_length = name_max_len
	if %PlayerName.text.is_empty():
		%PlayerName.text = "%s%03d" % [NAME_PREFIX, randi() % NAME_SUFFIX_RANGE]
	%IpRow.visible = OS.is_debug_build()
	%ConnectButton.pressed.connect(_on_connect)
	%PlayerName.text_submitted.connect(_on_name_submitted)
	%ConnectBack.pressed.connect(back_requested.emit)
	%ConnectStatus.text = LobbyText.OFFLINE


## A line under the buttons («Sin conexión», the reason a link was lost…).
func show_message(text: String) -> void:
	%ConnectStatus.text = text


func set_busy(busy: bool) -> void:
	%ConnectButton.disabled = busy
	%PlayerName.editable = not busy
	if busy:
		%ConnectStatus.text = LobbyText.CONNECTING


func _on_connect() -> void:
	var chosen: String = %PlayerName.text.strip_edges()
	if chosen.is_empty():
		show_message(LobbyText.error_text("bad_name"))
		return
	var server: String = %Ip.text.strip_edges()
	connect_requested.emit(chosen, server)


func _on_name_submitted(_text: String) -> void:
	_on_connect()
