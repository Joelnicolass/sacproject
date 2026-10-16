class_name MpMatchmaker
extends Node

## FIFO party assembler. Uses MpKit.rooms. Instant: no Accept, no scene change, no nick.

signal match_assembled(room_id: StringName, peer_ids: PackedInt32Array)

@export var party_size: int = 2

var _queue: Array[int] = []


func _ready() -> void:
	if not MpKit.peer_left.is_connected(_on_kit_peer_left):
		MpKit.peer_left.connect(_on_kit_peer_left)
	if MpKit.rooms != null and not MpKit.rooms.peer_seated.is_connected(_on_peer_seated):
		MpKit.rooms.peer_seated.connect(_on_peer_seated)


func _exit_tree() -> void:
	if MpKit.peer_left.is_connected(_on_kit_peer_left):
		MpKit.peer_left.disconnect(_on_kit_peer_left)
	if MpKit.rooms != null and MpKit.rooms.peer_seated.is_connected(_on_peer_seated):
		MpKit.rooms.peer_seated.disconnect(_on_peer_seated)


func enqueue(peer_id: int) -> void:
	if not MpKit.is_server():
		return
	if peer_id <= 0:
		return
	if is_queued(peer_id):
		return
	if MpKit.rooms != null and MpKit.rooms.seat_for_peer(peer_id) >= 0:
		return
	_queue.append(peer_id)
	_try_assemble()


func dequeue(peer_id: int) -> void:
	_queue.erase(peer_id)


func queued_count() -> int:
	return _queue.size()


func is_queued(peer_id: int) -> bool:
	return peer_id in _queue


func reset() -> void:
	_queue.clear()


func _on_kit_peer_left(peer_id: int, _slot: int) -> void:
	dequeue(peer_id)


func _on_peer_seated(_room_id: StringName, peer_id: int, _seat: int) -> void:
	dequeue(peer_id)


func _try_assemble() -> void:
	if not MpKit.is_server() or MpKit.rooms == null:
		return
	if party_size < 1:
		return
	while queued_count() >= party_size:
		var room_id := MpKit.rooms.create_room(party_size)
		if room_id == &"":
			return
		var party := PackedInt32Array()
		for _i in party_size:
			party.append(_queue.pop_front())
		for peer_id in party:
			MpKit.rooms.join_room(int(peer_id), room_id)
		match_assembled.emit(room_id, party)
