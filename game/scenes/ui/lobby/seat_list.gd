class_name SeatList
extends VBoxContainer

## The seats of a room, grouped by team when the room's mode has allies (2v2: «Equipo 1» with seats 1 and 2,
## «Equipo 2» with 3 and 4); one group with no title otherwise (1v1, all against all). One `seat_scene` row per seat, inside a
## `team_scene` group. It only shows the room Dictionary of the lobby mirror and passes on what the rows ask.

signal sit_requested(seat: int)
signal bot_add_requested(seat: int)
signal bot_remove_requested(seat: int)

## One row per seat (seat_row.tscn).
@export var seat_scene: PackedScene
## One group per team (team_group.tscn: %TeamTitle and %TeamSeats).
@export var team_scene: PackedScene
## Title of a team group; `%d` is the team number, from 1.
@export var team_title := "UI_ROOM_VIEW_TEAM"

var _rows: Array[SeatRow] = []
## Mode and number of seats the groups were built for.
var _layout := ""


## `room`: the room view of the server (empty = no room). `am_host`: this player may add and remove bots.
func show_room(room: Dictionary, am_host: bool) -> void:
	var seats: Array = room.get("seats", [])
	var options := room.get("options", {}) as Dictionary
	var layout := "%s/%d" % [str(options.get("mode", "")), seats.size()]
	if layout != _layout:
		_build(MatchWire.mode_in(options), seats.size())
		_layout = layout
	var open := not room.is_empty() and int(room["state"]) == MpLobbyRooms.State.OPEN
	for i in seats.size():
		var seat: Dictionary = seats[i]
		_rows[i].show_seat(seat, open and not bool(seat.get("you", false)), open and am_host)


## The row of the seat `index` (0-based); null if there is none.
func row(index: int) -> SeatRow:
	return _rows[index] if index >= 0 and index < _rows.size() else null


## The team groups, in order.
func groups() -> Array[Node]:
	return get_children()


func _build(mode: GameMode, count: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	if count == 0:
		return
	var by_team := mode != null and mode.has_allies()
	var groups_by_team := {}
	for i in count:
		var team := mode.team_of(i + 1) if by_team else 0
		if not groups_by_team.has(team):
			var group := team_scene.instantiate()
			var title := group.get_node(^"%TeamTitle") as Label
			title.visible = by_team
			title.text = tr(team_title) % (team + 1)
			add_child(group)
			groups_by_team[team] = group
		var seat_row := seat_scene.instantiate() as SeatRow
		seat_row.sit_requested.connect(sit_requested.emit)
		seat_row.bot_add_requested.connect(bot_add_requested.emit)
		seat_row.bot_remove_requested.connect(bot_remove_requested.emit)
		(groups_by_team[team] as Node).get_node(^"%TeamSeats").add_child(seat_row)
		_rows.append(seat_row)
