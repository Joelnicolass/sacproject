extends Control

## The room the player is in: players and their seats, the wizard and god, «Estoy listo», the countdown,
## the chat, and the result of the last match. It only reads the mirror of `MpLobby.client` and sends its commands.
## The wizard and god come from the same selector the menu uses (`character_select.tscn`, built the first time it is
## asked for). A player who never opens it takes the pick the menu left in `SacrificeFlow.pick`.
## The seats are a SeatList (grouped by team in a mode with allies); the host sees «Agregar IA» / «Quitar IA» on
## the seats and, above them, the god and the difficulty of the bot he adds (%BotOptions).
## Run alone (F6) it says «Sin conexión».

@export var character_select_scene: PackedScene
## What the selector's button says here (in the menu it says «Jugar»).
@export var pick_confirm_text := "UI_ROOM_VIEW_PICK_CONFIRM"

var _character_select: Control
## The room whose seat already got the menu's pick (once per room).
var _auto_picked_room := ""


func _ready() -> void:
	%PickCharacter.pressed.connect(_on_pick_pressed)
	%ReadyButton.pressed.connect(_on_ready_pressed)
	%LeaveRoom.pressed.connect(_on_leave)
	%RejoinMatch.pressed.connect(_on_rejoin)
	%PickOverlay.visible = false
	var seat_list: SeatList = %Seats
	seat_list.sit_requested.connect(_on_sit)
	seat_list.bot_add_requested.connect(_on_add_bot)
	seat_list.bot_remove_requested.connect(_on_remove_bot)
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
	%RejoinMatch.visible = false
	if not inside:
		%RoomTitle.text = tr(LobbyText.OFFLINE)
		%RoomMeta.text = ""
		%RoomPlayers.text = ""
		%RoomState.text = ""
		%RoomCountdown.text = ""
		%RoomResult.text = ""
		%BotOptions.visible = false
		(%Seats as SeatList).show_room({}, false)
		%PickOverlay.visible = false
		return
	%RoomTitle.text = str(room["name"])
	%RoomMeta.text = _meta_text(room)
	var seats: Array = room["seats"]
	var used := 0
	for seat: Dictionary in seats:
		if not bool(seat["free"]):
			used += 1
	%RoomPlayers.text = tr("UI_ROOM_VIEW_PLAYERS") % [used, seats.size()]
	var state := int(room["state"])
	%RoomState.text = LobbyText.state_text(state)
	var open := state == MpLobbyRooms.State.OPEN
	(%Seats as SeatList).show_room(room, client.is_host())
	%BotOptions.visible = open and client.is_host()
	%PickCharacter.disabled = not open
	%ReadyButton.disabled = state > MpLobbyRooms.State.COUNTDOWN
	# The match runs and this player is out of it (a drop): the same ticket takes the same slot back
	# while the dedicated allows it (`rejoin_grace_s`); past that the server turns the player away.
	%RejoinMatch.visible = (
		state == MpLobbyRooms.State.IN_MATCH
		and not MpKit.is_networked()
		and not client.last_match().is_empty()
	)
	var mine := _my_seat(room)
	var is_ready := bool(mine.get("ready", false))
	%ReadyButton.text = tr("UI_ROOM_VIEW_NOT_READY") if is_ready else tr("UI_ROOM_VIEW_READY")
	# The last match's result, until the next one starts.
	%RoomResult.text = (
		LobbyText.result_text(room["last_result"], client.my_seat() + 1)
		if state != MpLobbyRooms.State.LAUNCHING and state != MpLobbyRooms.State.IN_MATCH
		else ""
	)
	_auto_pick(room, mine, open)
	_show_progress(room)


## The countdown and the launch, line by line (also called each frame while counting).
func _show_progress(room: Dictionary) -> void:
	var state := int(room["state"])
	match state:
		MpLobbyRooms.State.COUNTDOWN:
			%RoomCountdown.text = (
				tr("UI_ROOM_VIEW_COUNTDOWN") % ceili(MpLobby.client.countdown_remaining())
			)
		MpLobbyRooms.State.LAUNCHING:
			%RoomCountdown.text = tr("UI_ROOM_VIEW_LAUNCHING")
		MpLobbyRooms.State.IN_MATCH:
			%RoomCountdown.text = tr("UI_ROOM_VIEW_IN_MATCH")
		_:
			%RoomCountdown.text = ""


func _meta_text(room: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(room["private"]) and room.has("code"):
		parts.append(tr("UI_ROOM_VIEW_CODE") % str(room["code"]))
	var options: Dictionary = room["options"]
	# The mode and the map the room was created with.
	var mode := MatchWire.mode_in(options)
	if mode != null:
		parts.append(tr("UI_ROOM_VIEW_MODE") % tr(mode.display_name))
	var map := MatchWire.map_in(options)
	if map != null:
		parts.append(tr("UI_ROOM_VIEW_MAP") % map.display_name)
	var land := MatchWire.land_in(options)
	if land != null:
		parts.append(tr("UI_ROOM_VIEW_LAND") % land.display_name)
	if options.has("level"):
		parts.append(tr("UI_ROOM_VIEW_LEVEL") % int(options["level"]))
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
	MpLobby.client.set_pick(MatchWire.encode_pick(SacrificeFlow.pick))


func _on_sit(seat: int) -> void:
	MpLobby.client.choose_seat(seat)


## The host puts a bot with the god and the difficulty of %BotOptions in a free seat.
func _on_add_bot(seat: int) -> void:
	var meta := {
		"god": MatchWire.encode_god((%BotGod as AiGodPicker).selected_god()),
		"difficulty": (%BotDifficulty as AiDifficultyPicker).selected_difficulty(),
	}
	MpLobby.client.set_seat_bot(seat, meta)


func _on_remove_bot(seat: int) -> void:
	MpLobby.client.clear_seat_bot(seat)


func _on_ready_pressed() -> void:
	var mine := _my_seat(MpLobby.client.room)
	MpLobby.client.set_ready(not bool(mine.get("ready", false)))


func _on_rejoin() -> void:
	var last := MpLobby.client.last_match()
	if last.is_empty():
		return
	SacrificeFlow.join_from_lobby(str(last["host"]), int(last["port"]), str(last["token"]))


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
	# Free the selector with the overlay: nothing of it can keep the pointer (it is built again if asked for).
	if _character_select != null:
		_character_select.queue_free()
		_character_select = null
	MpLobby.client.set_pick(MatchWire.encode_pick(SacrificeFlow.pick))
