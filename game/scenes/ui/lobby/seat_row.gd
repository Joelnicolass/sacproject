extends HBoxContainer

## RFC-034 034f: one seat of the room: who sits there, their wizard and god, if they are ready, and «Sentarme aquí»
## when the seat is free. It shows what the view hands it (`show_seat`); the only thing it does is ask.

signal sit_requested(seat: int)

const READY_TEXT := "Listo"
const NOT_READY_TEXT := "Esperando"
const YOU_SUFFIX := " (vos)"
const AWAY_SUFFIX := " (sin conexión)"

var _seat: int = -1


func _ready() -> void:
	%Sit.pressed.connect(_on_sit)


## `seat`: one row of the room view from the server ({seat, free, name, meta, ready, connected, you}).
## `can_sit`: the room is open and I may move.
func show_seat(seat: Dictionary, can_sit: bool) -> void:
	_seat = int(seat["seat"])
	var is_free := bool(seat["free"])
	if is_free:
		%SeatName.text = LobbyText.FREE_SEAT
		%SeatPick.text = ""
		%SeatReady.text = ""
		%Sit.visible = true
		%Sit.disabled = not can_sit
		return
	var suffix := YOU_SUFFIX if bool(seat["you"]) else ""
	if not bool(seat["connected"]):
		suffix += AWAY_SUFFIX
	%SeatName.text = str(seat["name"]) + suffix
	%SeatPick.text = LobbyText.pick_text(seat["meta"])
	%SeatReady.text = READY_TEXT if bool(seat["ready"]) else NOT_READY_TEXT
	%Sit.visible = false


func _on_sit() -> void:
	sit_requested.emit(_seat)
