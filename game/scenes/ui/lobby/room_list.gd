extends Control

## RFC-034 034f: the open rooms of the server. One button per room (pressing it joins), «Actualizar», «Crear sala»,
## a code for the private ones. It only reads `MpLobby.client` and calls its commands; the screen decides which view
## shows. Run alone (F6) it says «Sin conexión».

signal create_requested
signal back_requested

## One button per room.
@export var row_scene: PackedScene


func _ready() -> void:
	%RefreshRooms.pressed.connect(_on_refresh)
	%CreateRoom.pressed.connect(create_requested.emit)
	%CodeJoin.pressed.connect(_on_code_join)
	%JoinCode.text_submitted.connect(_on_code_submitted)
	%ListBack.pressed.connect(back_requested.emit)
	MpLobby.client.room_list_received.connect(_on_rooms)
	MpLobby.client.lobby_joined.connect(_on_online_changed)
	MpLobby.client.lobby_lost.connect(_on_lost)
	_refresh()


func _refresh() -> void:
	var online := MpLobby.client.is_online()
	%RefreshRooms.disabled = not online
	%CreateRoom.disabled = not online
	%CodeJoin.disabled = not online
	_fill(MpLobby.client.rooms if online else [])


func _fill(rows: Array) -> void:
	var holder: Control = %Rooms
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if not MpLobby.client.is_online():
		%ListStatus.text = LobbyText.OFFLINE
		return
	%ListStatus.text = "" if not rows.is_empty() else LobbyText.NO_ROOMS
	for row: Dictionary in rows:
		var button := row_scene.instantiate() as Button
		var used := int(row["seats_used"])
		var seats := int(row["seats"])
		var state := int(row["state"])
		button.text = "%s · %d/%d · %s" % [str(row["name"]), used, seats, LobbyText.state_text(state)]
		button.disabled = state != MpLobbyRooms.State.OPEN or used >= seats
		button.pressed.connect(_on_row.bind(str(row["id"])))
		holder.add_child(button)


func _on_rooms(rows: Array) -> void:
	_fill(rows)


func _on_online_changed(_session_id: String) -> void:
	_refresh()


func _on_lost(_reason: String) -> void:
	_refresh()


func _on_refresh() -> void:
	MpLobby.client.refresh_rooms()


func _on_row(room_id: String) -> void:
	MpLobby.client.join_room(room_id)


func _on_code_join() -> void:
	var code: String = %JoinCode.text.strip_edges()
	if not code.is_empty():
		MpLobby.client.join_code(code)


func _on_code_submitted(_text: String) -> void:
	_on_code_join()
