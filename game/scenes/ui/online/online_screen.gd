extends Control

## «Salas online»: rooms the players host through the issuer. A door with three buttons: create a room, join one (by its code or
## from the list), or go back. It owns no state: the two views do the work and the status line shows what SacrificeFlow says.
## Not: the room (MpOnline in the kit), the ticket (OnlineTicket), the room-server lobby (scenes/ui/lobby/).

@onready var _menu: Control = %OnlineMenu
@onready var _host_view: Control = %OnlineHostView
@onready var _join_view: Control = %OnlineJoinView
@onready var _network: OnlineNetwork = %OnlineNetwork
@onready var _status: Label = %OnlineStatus


func _ready() -> void:
	_network.apply()
	SacrificeFlow.status_changed.connect(_on_status)
	%CreateOnline.pressed.connect(_show.bind(_host_view))
	%JoinOnline.pressed.connect(_show.bind(_join_view))
	%OnlineBack.pressed.connect(_on_menu)
	_host_view.back_requested.connect(_show.bind(_menu))
	_join_view.back_requested.connect(_show.bind(_menu))
	_show(_menu)


func _show(view: Control) -> void:
	_status.text = ""
	for candidate: Control in [_menu, _host_view, _join_view]:
		candidate.visible = candidate == view


func _on_status(text: String) -> void:
	_status.text = text


func _on_menu() -> void:
	# By path, like the other network screens: the menu points to this screen.
	get_tree().change_scene_to_file(SacrificeFlow.boot_path)
