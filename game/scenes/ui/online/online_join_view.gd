extends Control

## Joins an online room: by the code a friend passed (typed as he likes: lower case and dashes are
## fine), or by a row of the list of public rooms of this game and version (refreshed each time the
## view shows). The pick is the menu's (`SacrificeFlow.pick`): the host's match takes it on
## admission. Not: the seat or the relay (MpFlow.join_online), the texts of a refusal (the status
## line).

signal back_requested

## One button per public room (online_room_row.tscn); the view sets its text and what it joins.
@export var room_row_scene: PackedScene

var _joining: bool = false

@onready var _code: LineEdit = %Code
@onready var _rows: Control = %RoomRows


func _ready() -> void:
	%JoinRoom.pressed.connect(_on_join_typed)
	_code.text_submitted.connect(_on_join_typed.unbind(1))
	%Refresh.pressed.connect(refresh)
	%JoinBack.pressed.connect(back_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	MpKit.admission_rejected.connect(_set_joining.bind(false).unbind(1))
	MpKit.join_failed.connect(_set_joining.bind(false))


## Asks the issuer for the public rooms and shows one row per room.
func refresh() -> void:
	%Refresh.disabled = true
	var rooms: Array = await SacrificeFlow.online_rooms()
	# The answer may come after this screen was left.
	if not is_inside_tree():
		return
	%Refresh.disabled = false
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for room: Dictionary in rooms:
		var row := room_row_scene.instantiate() as Button
		row.text = (
			tr("UI_ONLINE_ROOM_ROW")
			% [
				str(room.get("name", "")),
				int(room.get("players", 0)),
				int(room.get("max_players", 0))
			]
		)
		row.pressed.connect(_join.bind(str(room.get("code", ""))))
		_rows.add_child(row)
	%NoRooms.visible = rooms.is_empty()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()


func _on_join_typed() -> void:
	_join(_code.text.strip_edges())


func _join(code: String) -> void:
	if _joining or code.is_empty():
		return
	_set_joining(true)
	var err: Error = await SacrificeFlow.join_online(code)
	if err != OK and is_inside_tree():
		_set_joining(false)


func _set_joining(joining: bool) -> void:
	_joining = joining
	%JoinRoom.disabled = joining
	for row: Button in _rows.get_children():
		row.disabled = joining
