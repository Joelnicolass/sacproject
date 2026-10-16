class_name MpRoomDirectory
extends Node

## Opt-in hub rooms on one dedicated process. Room seat ≠ hub slot.
## Empty rooms count toward max_rooms until close_room. No gameplay.
##
## Headless smoke (debugger on the dedicated process, after host_dedicated + joins):
##   MpKit.matchmaker.enqueue(MpKit.peer_id_for(1))
##   MpKit.matchmaker.enqueue(MpKit.peer_id_for(2))
##   → match_assembled: one room_id, seats 0 and 1. A second pair → a different room_id.
##   Direct: create_room() then join_room_by_code(peer, code). Alphabet has no 0O1I.
##   push_snapshot_to_room(A) must not arrive as that dict on peers of B.

const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

signal room_created(room_id: StringName, code: String)
signal peer_seated(room_id: StringName, peer_id: int, seat: int)
signal room_ready(room_id: StringName)
signal peer_unseated(room_id: StringName, peer_id: int, seat: int)
signal room_closed(room_id: StringName)
signal room_assigned(room_id: StringName, seat: int)

@export var max_rooms: int = 16
@export var seats_per_room: int = 2
@export var code_length: int = 4

var _rng := RandomNumberGenerator.new()
var _next_room_serial: int = 0
var _rooms: Dictionary = {}
var _peer_to_room: Dictionary = {}
var _code_to_room: Dictionary = {}


class _Room extends RefCounted:
	var id: StringName = &""
	var code: String = ""
	var seats: int = 2
	var occupants: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_rng.randomize()
	MpAuthority.claim_server(self)
	if not MpKit.peer_left.is_connected(_on_kit_peer_left):
		MpKit.peer_left.connect(_on_kit_peer_left)


func _exit_tree() -> void:
	if MpKit.peer_left.is_connected(_on_kit_peer_left):
		MpKit.peer_left.disconnect(_on_kit_peer_left)


func create_room(seats: int = -1) -> StringName:
	if not _can_mutate():
		return StringName()
	var seat_count := seats_per_room if seats < 0 else seats
	if seat_count < 1:
		return StringName()
	if _rooms.size() >= max_rooms:
		return StringName()
	var code := _make_unique_code()
	if code.is_empty():
		return StringName()
	var room := _Room.new()
	room.id = _next_id()
	room.code = code
	room.seats = seat_count
	room.occupants.resize(seat_count)
	_rooms[room.id] = room
	_code_to_room[code] = room.id
	room_created.emit(room.id, code)
	return room.id


func join_room(peer_id: int, room_id: StringName) -> Error:
	if not _can_mutate():
		return FAILED
	if peer_id <= 0:
		return ERR_INVALID_PARAMETER
	var room := _room(room_id)
	if room == null:
		return ERR_DOES_NOT_EXIST
	var existing_seat := _seat_of(room, peer_id)
	if existing_seat >= 0:
		_push_assignment(peer_id, room_id, existing_seat)
		return OK
	var current := room_id_for_peer(peer_id)
	if current != &"" and current != room_id:
		leave_room(peer_id)
	var seat := _next_free_seat(room)
	if seat < 0:
		return ERR_BUSY
	room.occupants[seat] = peer_id
	_peer_to_room[peer_id] = room.id
	peer_seated.emit(room.id, peer_id, seat)
	_push_assignment(peer_id, room.id, seat)
	if _is_full(room):
		room_ready.emit(room.id)
	return OK


func join_room_by_code(peer_id: int, code: String) -> Error:
	if not _can_mutate():
		return FAILED
	var normalized := code.strip_edges().to_upper()
	if normalized.is_empty():
		return ERR_INVALID_PARAMETER
	if not _code_to_room.has(normalized):
		return ERR_DOES_NOT_EXIST
	return join_room(peer_id, _code_to_room[normalized])


func leave_room(peer_id: int) -> void:
	if not _can_mutate():
		return
	var room_id := room_id_for_peer(peer_id)
	if room_id == &"":
		return
	var room := _room(room_id)
	_peer_to_room.erase(peer_id)
	if room == null:
		return
	var seat := _seat_of(room, peer_id)
	if seat < 0:
		return
	room.occupants[seat] = 0
	peer_unseated.emit(room_id, peer_id, seat)


func close_room(room_id: StringName) -> void:
	if not _can_mutate():
		return
	var room := _room(room_id)
	if room == null:
		return
	for seat in range(room.occupants.size()):
		var peer_id := int(room.occupants[seat])
		if peer_id == 0:
			continue
		_peer_to_room.erase(peer_id)
		room.occupants[seat] = 0
		peer_unseated.emit(room_id, peer_id, seat)
	_code_to_room.erase(room.code)
	_rooms.erase(room_id)
	room_closed.emit(room_id)


func reset() -> void:
	_rooms.clear()
	_peer_to_room.clear()
	_code_to_room.clear()
	_next_room_serial = 0


func room_id_for_peer(peer_id: int) -> StringName:
	return _peer_to_room.get(peer_id, StringName()) as StringName


func seat_for_peer(peer_id: int) -> int:
	var room := _room(room_id_for_peer(peer_id))
	if room == null:
		return -1
	return _seat_of(room, peer_id)


func peer_for_seat(room_id: StringName, seat: int) -> int:
	var room := _room(room_id)
	if room == null:
		return 0
	if seat < 0 or seat >= room.occupants.size():
		return 0
	return int(room.occupants[seat])


func peers_in_room(room_id: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	var room := _room(room_id)
	if room == null:
		return out
	for peer_id in room.occupants:
		if int(peer_id) != 0:
			out.append(int(peer_id))
	return out


func code_for_room(room_id: StringName) -> String:
	var room := _room(room_id)
	if room == null:
		return ""
	return room.code


func is_room_full(room_id: StringName) -> bool:
	var room := _room(room_id)
	if room == null:
		return false
	return _is_full(room)


func room_count() -> int:
	return _rooms.size()


func push_snapshot_to_room(room_id: StringName, data: Dictionary) -> void:
	if not MpKit.is_server():
		return
	for peer_id in peers_in_room(room_id):
		MpKit.push_snapshot_to(peer_id, data)


func push_custom_to_room(room_id: StringName, channel: StringName, data: Dictionary) -> void:
	if not MpKit.is_server():
		return
	for peer_id in peers_in_room(room_id):
		MpKit.push_custom_to(peer_id, channel, data)


@rpc("authority", "call_remote", "reliable")
func rpc_assign_room(room_id: String, seat: int) -> void:
	room_assigned.emit(StringName(room_id), seat)


func _can_mutate() -> bool:
	return MpKit.is_server()


func _on_kit_peer_left(peer_id: int, _slot: int) -> void:
	leave_room(peer_id)


func _room(room_id: StringName) -> _Room:
	if not _rooms.has(room_id):
		return null
	return _rooms[room_id] as _Room


func _next_id() -> StringName:
	_next_room_serial += 1
	return StringName("r_%d" % _next_room_serial)


func _make_unique_code() -> String:
	for _i in 64:
		var code := _random_code()
		if code.is_empty():
			return ""
		if not _code_to_room.has(code):
			return code
	return ""


func _random_code() -> String:
	if code_length < 1:
		return ""
	var n := CODE_ALPHABET.length()
	var out := ""
	for _i in code_length:
		out += CODE_ALPHABET[_rng.randi() % n]
	return out


func _seat_of(room: _Room, peer_id: int) -> int:
	for seat in range(room.occupants.size()):
		if int(room.occupants[seat]) == peer_id:
			return seat
	return -1


func _next_free_seat(room: _Room) -> int:
	for seat in range(room.occupants.size()):
		if int(room.occupants[seat]) == 0:
			return seat
	return -1


func _is_full(room: _Room) -> bool:
	return _next_free_seat(room) < 0


func _push_assignment(peer_id: int, room_id: StringName, seat: int) -> void:
	if not MpKit.is_networked() or not is_inside_tree():
		return
	if peer_id == multiplayer.get_unique_id():
		room_assigned.emit(room_id, seat)
		return
	for connected in multiplayer.get_peers():
		if int(connected) == peer_id:
			rpc_assign_room.rpc_id(peer_id, String(room_id), seat)
			return
