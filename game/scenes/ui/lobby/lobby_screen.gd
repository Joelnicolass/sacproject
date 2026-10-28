extends Control

## The room screens of Sacrifice. It owns no state: the views read `MpLobby.client` (the kit's mirror of
## the room server) and this node only decides which one shows (connect, list, create, room), turns the client's
## errors into one notice, and takes the player into the match when the server says it is ready
## (`SacrificeFlow.join_from_lobby`). The lobby link lives in the `MpLobby` autoload, so it survives the match: when the
## match ends the flow brings the player back here and the room is still there, with the result.
## Run alone (F6) it shows the connect view with «Sin conexión»; it never connects by itself.

## Where the room server is. `--lobby=host:port` wins over the saved values.
@export var endpoint: MpLobbyEndpoint
## How the online rooms are reached (the relay); applied here, so solo, LAN and «Servidor local» keep ENet.
@export var online: OnlineNetwork
## Seconds a notice stays on screen.
@export var notice_s: float = 4.0

## The view to show while the player is creating a room.
var _creating := false

@onready var _connect_view: Control = %LobbyConnect
@onready var _list_view: Control = %RoomList
@onready var _create_view: Control = %RoomCreate
@onready var _room_view: Control = %RoomView
@onready var _notice: Label = %Notice
@onready var _notice_timer: Timer = %NoticeTimer


func _ready() -> void:
	_notice_timer.wait_time = notice_s
	_notice_timer.timeout.connect(_clear_notice)
	_connect_view.connect_requested.connect(_on_connect_requested)
	_connect_view.back_requested.connect(_on_menu)
	_list_view.create_requested.connect(_on_create_requested)
	_list_view.back_requested.connect(_on_menu)
	_create_view.cancelled.connect(_on_create_cancelled)
	var client := MpLobby.client
	# A lobby drop (also in a match) is not the end: it comes back with its token and keeps its seat (`resume_grace_s`).
	client.auto_resume = true
	client.lobby_resuming.connect(_on_lobby_resuming)
	client.lobby_joined.connect(_on_lobby_joined)
	client.lobby_lost.connect(_on_lobby_lost)
	client.rejected.connect(_on_rejected)
	client.room_updated.connect(_on_room_updated)
	client.room_left.connect(_refresh)
	client.error_received.connect(_on_error)
	client.match_ready.connect(_on_match_ready)
	MpKit.admission_rejected.connect(_on_admission_rejected)
	_clear_notice()
	_refresh()


## The one view that matches what the client says now.
func _refresh() -> void:
	var client := MpLobby.client
	var view: Control = _connect_view
	if client.is_online():
		if not client.room.is_empty():
			view = _room_view
		elif _creating:
			view = _create_view
		else:
			view = _list_view
	for candidate: Control in [_connect_view, _list_view, _create_view, _room_view]:
		candidate.visible = candidate == view
	_connect_view.set_busy(client.link == MpLobbyClient.Link.CONNECTING or client.is_resuming())


func _on_connect_requested(display_name: String, host_override: String) -> void:
	var where := endpoint.resolved() if endpoint != null else MpLobbyEndpoint.new()
	var host := host_override if not host_override.is_empty() else where.host
	online.apply()
	print(
		(
			'lobby screen: connecting to %s:%d (%s) as "%s"'
			% [host, where.port, MpLobby.client.transport, display_name]
		)
	)
	var err := MpLobby.connect_to(host, where.port, display_name)
	if err != OK:
		_connect_view.show_message(LobbyText.lost_text("connect_failed"))
		return
	_refresh()


func _on_lobby_joined(_session_id: String) -> void:
	_creating = false
	MpLobby.client.refresh_rooms()
	_refresh()


func _on_lobby_lost(reason: String) -> void:
	print("lobby screen: connection lost (%s)" % reason)
	_creating = false
	_refresh()
	_connect_view.show_message(LobbyText.lost_text(reason))


func _on_lobby_resuming(_attempt: int) -> void:
	_refresh()
	_connect_view.show_message(tr(LobbyText.RESUMING))


func _on_rejected(code: String) -> void:
	_refresh()
	_connect_view.show_message(LobbyText.error_text(code))


func _on_create_requested() -> void:
	_creating = true
	_refresh()


func _on_create_cancelled() -> void:
	_creating = false
	_refresh()


func _on_room_updated(_room: Dictionary) -> void:
	_creating = false
	_refresh()


func _on_error(code: String) -> void:
	_show_notice(LobbyText.error_text(code))


## The room server says the match listens: join its dedicated with the one-use ticket.
func _on_match_ready(host: String, port: int, token: String) -> void:
	_show_notice(tr(LobbyText.ENTERING_MATCH))
	var err: Error = SacrificeFlow.join_from_lobby(host, port, token)
	if err != OK:
		_show_notice(LobbyText.error_text("match_failed"))


func _on_admission_rejected(_reason: String) -> void:
	_show_notice(LobbyText.error_text("match_failed"))


func _on_menu() -> void:
	SacrificeFlow.from_lobby = false
	MpLobby.client.close_connection()
	# By path: the menu points to this screen, so the screen cannot hold the menu as a resource (cyclic).
	get_tree().change_scene_to_file(SacrificeFlow.boot_path)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_timer.start()


func _clear_notice() -> void:
	_notice.visible = false
