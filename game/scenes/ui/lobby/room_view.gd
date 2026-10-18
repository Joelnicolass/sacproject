extends Control

## RFC-034 034f: the room the player is in: players and their seats, the wizard and god, «Estoy listo», the countdown,
## the chat, and the result of the last match. It only reads the mirror of `MpLobby.client` and sends its commands.
## The wizard and god come from the same selector the menu uses (`character_select.tscn`, built the first time it is
## asked for). A player who never opens it takes the pick the menu left in `SacrificeFlow.pick`.
## Run alone (F6) it says «Sin conexión».

## One row per seat.
@export var seat_scene: PackedScene
@export var character_select_scene: PackedScene
## What the selector's button says here (in the menu it says «Jugar»).
@export var pick_confirm_text := "Elegir"

var _seat_rows: Array[Node] = []
var _character_select: Control
## The room whose seat already got the menu's pick (once per room).
var _auto_picked_room := ""


func _ready() -> void:
	%PickCharacter.pressed.connect(_on_pick_pressed)
	%ReadyButton.pressed.connect(_on_ready_pressed)
	%LeaveRoom.pressed.connect(_on_leave)
	%PickOverlay.visible = false
	var client := MpLobby.client
	client.room_updated.connect(_on_room)
	client.room_left.connect(_refresh)
	client.lobby_lost.connect(_on_lost)
	_refresh()


func _process(_delta: float) -> void:
	var room := MpLobby.client.room
	if room.is_empty():
		return
	_show_progress(room)


func _on_room(_room: Dictionary) -> void:
	_refresh()


func _on_lost(_reason: String) -> void:
	_refresh()


func _refresh() -> void:
	var client := MpLobby.client
	var room := client.room
	var inside := client.is_online() and not room.is_empty()
	%PickCharacter.disabled = not inside
	%ReadyButton.disabled = not inside
	%LeaveRoom.disabled = not inside
	if not inside:
		%RoomTitle.text = LobbyText.OFFLINE
		%RoomMeta.text = ""
		%RoomPlayers.text = ""
		%RoomState.text = ""
		%RoomCountdown.text = ""
		%RoomResult.text = ""
		_set_rows([])
		%PickOverlay.visible = false
		return
	%RoomTitle.text = str(room["name"])
	%RoomMeta.text = _meta_text(room)
	var seats: Array = room["seats"]
	var used := 0
	for seat: Dictionary in seats:
		if not bool(seat["free"]):
			used += 1
	%RoomPlayers.text = "Jugadores: %d/%d" % [used, seats.size()]
	var state := int(room["state"])
	%RoomState.text = LobbyText.state_text(state)
	var open := state == MpLobbyRooms.State.OPEN
	_set_rows(seats)
	%PickCharacter.disabled = not open
	%ReadyButton.disabled = state > MpLobbyRooms.State.COUNTDOWN
	var mine := _my_seat(room)
	var is_ready := bool(mine.get("ready", false))
	%ReadyButton.text = "Ya no estoy listo" if is_ready else "Estoy listo"
	## The last match's result, until the next one starts.
	%RoomResult.text = LobbyText.result_text(room["last_result"], client.my_seat() + 1) if state != MpLobbyRooms.State.LAUNCHING and state != MpLobbyRooms.State.IN_MATCH else ""
	_auto_pick(room, mine, open)
	_show_progress(room)


## The countdown and the launch, line by line (also called each frame while counting).
func _show_progress(room: Dictionary) -> void:
	var state := int(room["state"])
	match state:
		MpLobbyRooms.State.COUNTDOWN:
			%RoomCountdown.text = "La partida empieza en %d…" % ceili(MpLobby.client.countdown_remaining())
		MpLobbyRooms.State.LAUNCHING:
			%RoomCountdown.text = "Preparando la partida…"
		MpLobbyRooms.State.IN_MATCH:
			%RoomCountdown.text = "Partida en curso"
		_:
			%RoomCountdown.text = ""


func _meta_text(room: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(room["private"]) and room.has("code"):
		parts.append("Código: %s" % str(room["code"]))
	var options: Dictionary = room["options"]
	if options.has("level"):
		parts.append("Nivel de los magos: %d" % int(options["level"]))
	return " · ".join(parts)


func _my_seat(room: Dictionary) -> Dictionary:
	for seat: Dictionary in room["seats"]:
		if bool(seat.get("you", false)):
			return seat
	return {}


## Sends the menu's pick the first time the player is in this room without one.
func _auto_pick(room: Dictionary, mine: Dictionary, open: bool) -> void:
	if mine.is_empty() or not open or _auto_picked_room == str(room["id"]):
		return
	if not (mine["meta"] as Dictionary).is_empty():
		return
	_auto_picked_room = str(room["id"])
	MpLobby.client.set_pick(SacrificeFlow.pick)


func _set_rows(seats: Array) -> void:
	while _seat_rows.size() > seats.size():
		var extra: Node = _seat_rows.pop_back()
		extra.queue_free()
	while _seat_rows.size() < seats.size():
		var row := seat_scene.instantiate()
		row.sit_requested.connect(_on_sit)
		%Seats.add_child(row)
		_seat_rows.append(row)
	var open := not MpLobby.client.room.is_empty() and int(MpLobby.client.room["state"]) == MpLobbyRooms.State.OPEN
	for i in seats.size():
		var seat: Dictionary = seats[i]
		(_seat_rows[i] as Node).call(&"show_seat", seat, open and not bool(seat.get("you", false)))


func _on_sit(seat: int) -> void:
	MpLobby.client.choose_seat(seat)


func _on_ready_pressed() -> void:
	var mine := _my_seat(MpLobby.client.room)
	MpLobby.client.set_ready(not bool(mine.get("ready", false)))


func _on_leave() -> void:
	MpLobby.client.leave_room()


func _on_pick_pressed() -> void:
	if _character_select == null:
		_character_select = character_select_scene.instantiate() as Control
		_character_select.set("confirm_text", pick_confirm_text)
		_character_select.connect("confirmed", _on_pick_confirmed)
		%PickHolder.add_child(_character_select)
	%PickOverlay.visible = true


func _on_pick_confirmed() -> void:
	%PickOverlay.visible = false
	## Free the selector with the overlay: nothing of it can keep the pointer (it is built again if asked for).
	if _character_select != null:
		_character_select.queue_free()
		_character_select = null
	MpLobby.client.set_pick(SacrificeFlow.pick)
