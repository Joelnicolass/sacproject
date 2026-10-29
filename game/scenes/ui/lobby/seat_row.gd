class_name SeatRow
extends HBoxContainer

## One seat of the room: who sits there, their wizard and god, if they are ready, and «Sentarme
## aquí» when the seat is free. It shows what the view hands it (`show_seat`); the only thing it
## does is ask. A bot seat shows «IA» with its god and difficulty; the host sees «Agregar IA» on a
## free seat and «Quitar IA» on a bot seat.

signal sit_requested(seat: int)
signal bot_add_requested(seat: int)
signal bot_remove_requested(seat: int)

const READY_TEXT := "UI_SEAT_READY"
const NOT_READY_TEXT := "UI_SEAT_WAITING"
const YOU_SUFFIX := " (vos)"
const AWAY_SUFFIX := "UI_SEAT_AWAY_SUFFIX"
const BOT_NAME := "LOBBY_BOT_NAME"

var _seat: int = -1


func _ready() -> void:
	%Sit.pressed.connect(_on_sit)
	%AddBot.pressed.connect(func() -> void: bot_add_requested.emit(_seat))
	%RemoveBot.pressed.connect(func() -> void: bot_remove_requested.emit(_seat))


## `seat`: one row of the room view from the server ({seat, free, bot, name, meta, ready, connected,
## you}). `can_sit`: the room is open and I may move. `can_manage_bots`: I am the host and the room
## is open.
func show_seat(seat: Dictionary, can_sit: bool, can_manage_bots := false) -> void:
	_seat = int(seat["seat"])
	var is_free := bool(seat["free"])
	var is_bot := bool(seat.get("bot", false))
	%Sit.visible = is_free
	%AddBot.visible = is_free and can_manage_bots
	%RemoveBot.visible = is_bot and can_manage_bots
	if is_free:
		%SeatName.text = tr(LobbyText.FREE_SEAT)
		%SeatPick.text = ""
		%SeatReady.text = ""
		%Sit.disabled = not can_sit
		return
	if is_bot:
		%SeatName.text = tr(BOT_NAME)
		%SeatPick.text = LobbyText.bot_text(seat["meta"])
		%SeatReady.text = tr(READY_TEXT)
		return
	var suffix := YOU_SUFFIX if bool(seat["you"]) else ""
	if not bool(seat["connected"]):
		suffix += " " + tr(AWAY_SUFFIX)
	%SeatName.text = str(seat["name"]) + suffix
	%SeatPick.text = LobbyText.pick_text(seat["meta"])
	%SeatReady.text = tr(READY_TEXT) if bool(seat["ready"]) else tr(NOT_READY_TEXT)


func _on_sit() -> void:
	sit_requested.emit(_seat)
