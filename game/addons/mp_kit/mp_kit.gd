extends Node

## Informal MP kit autoload. ENet + slots + session RPCs. No game rules.
## Listen-server: host() — hosting player is slot 1 / peer 1.
## Dedicated: host_dedicated() — peer 1 is not a player; same project as clients (VPS / --dedicated).

signal peer_joined(peer_id: int, slot: int)
signal peer_left(peer_id: int, slot: int)
signal join_failed
signal server_lost
signal client_world_ready(peer_id: int)
signal load_world
signal snapshot_received(data: Dictionary)
signal session_ended(data: Dictionary)
signal slot_assigned(slot: int)
## Opaque Dictionary pipe. Kit does not interpret `data`. from_peer is 1 when the server pushed.
signal custom_received(channel: StringName, data: Dictionary, from_peer: int)

var port: int = 7777
var max_players: int = 2
## Empty = every channel. Non-empty = drop unknown names (controlled low-level).
var custom_channels: PackedStringArray = PackedStringArray()
var ids: MpIds = MpIds.new()
var rooms: MpRoomDirectory
var matchmaker: MpMatchmaker

var _peer: ENetMultiplayerPeer
var _world_ready: Dictionary = {}
var _broadcasting_custom: bool = false


func _ready() -> void:
	_ensure_hub_children()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func configure(
	p_port: int,
	p_max_players: int,
	host_slot: int = 1,
	p_custom_channels: PackedStringArray = PackedStringArray()
) -> void:
	port = p_port
	max_players = p_max_players
	ids.max_players = p_max_players
	ids.host_slot = host_slot
	custom_channels = p_custom_channels


func is_networked() -> bool:
	return _peer != null and multiplayer.multiplayer_peer == _peer


func is_server() -> bool:
	return is_networked() and multiplayer.is_server()


func is_dedicated() -> bool:
	return is_server() and ids.dedicated


func is_listen_host() -> bool:
	return is_server() and not ids.dedicated


func local_slot() -> int:
	if not is_networked():
		return ids.host_slot
	if multiplayer.is_server():
		if ids.dedicated:
			return 0
		return ids.host_slot
	if ids.local_slot != 0:
		return ids.local_slot
	return ids.host_slot + 1


func occupied_slots() -> Array[int]:
	return ids.occupied_slots()


func peer_id_for(slot: int) -> int:
	return ids.peer_id_for(slot)


func slot_for_peer(peer_id: int) -> int:
	return ids.slot_for_peer(peer_id)


func exceeds_max_players(player_count: int) -> bool:
	return player_count > max_players


func is_peer_world_ready(peer_id: int) -> bool:
	return bool(_world_ready.get(peer_id, false))


func host(dedicated: bool = false) -> Error:
	leave()
	ids.dedicated = dedicated
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, _enet_max_clients())
	if err != OK:
		ids.dedicated = false
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	if dedicated:
		ids.reset_dedicated()
	else:
		ids.reset_host()
	_world_ready.clear()
	return OK


func host_dedicated() -> Error:
	return host(true)


func join(address: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_peer = peer
	multiplayer.multiplayer_peer = peer
	ids.reset_offline()
	ids.local_slot = 0
	_world_ready.clear()
	return OK


func leave() -> void:
	if rooms:
		rooms.reset()
	if matchmaker:
		matchmaker.reset()
	_world_ready.clear()
	ids.reset_offline()
	## Keep Rooms / Matchmaker. Only free LAN beacon and late-join helper.
	for child in get_children():
		if child is MpLanBeacon or child.name == "MpBootLateJoin":
			child.queue_free()
	if _peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		return
	var closing := _peer
	_peer = null
	closing.close()
	if multiplayer.multiplayer_peer == closing:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func request_world_ready() -> void:
	if not is_networked() or multiplayer.is_server():
		return
	rpc_world_ready.rpc_id(1)


func push_snapshot(data: Dictionary) -> void:
	if not is_server():
		return
	rpc_snapshot.rpc(data)


func push_snapshot_to(peer_id: int, data: Dictionary) -> void:
	if not is_server():
		return
	rpc_snapshot.rpc_id(peer_id, data)


## Peers reload the world: their world_ready (and spawner reveals) start over.
func broadcast_load_world() -> void:
	if not is_server():
		return
	_world_ready.clear()
	rpc_load_world.rpc()


func load_world_to(peer_id: int) -> void:
	if not is_server():
		return
	_world_ready.erase(peer_id)
	rpc_load_world.rpc_id(peer_id)


func broadcast_session_ended(data: Dictionary) -> void:
	if not is_server():
		return
	rpc_session_ended.rpc(data)


func is_custom_channel_allowed(channel: StringName) -> bool:
	if custom_channels.is_empty():
		return true
	var name := String(channel)
	for allowed in custom_channels:
		if allowed == name:
			return true
	return false


## Client → server (or local if offline / already server). Does not auto-broadcast.
func send_custom(channel: StringName, data: Dictionary) -> void:
	if not is_custom_channel_allowed(channel):
		return
	var payload: Dictionary = data.duplicate(true)
	if not is_networked() or is_server():
		var peer_id := 1
		if is_networked():
			peer_id = multiplayer.get_unique_id()
		custom_received.emit(channel, payload, peer_id)
		return
	rpc_custom_to_server.rpc_id(1, String(channel), payload)


## Server → every client (and emit on the server). call_remote: clients only get the RPC.
## Re-entrant: glue must not `broadcast_custom` again from this emit without checking `from_peer`.
## A nested call is ignored so a naive `if is_server(): broadcast_custom` cannot recurse.
func broadcast_custom(channel: StringName, data: Dictionary) -> void:
	if not is_server():
		return
	if not is_custom_channel_allowed(channel):
		return
	if _broadcasting_custom:
		return
	_broadcasting_custom = true
	var payload: Dictionary = data.duplicate(true)
	custom_received.emit(channel, payload, 1)
	rpc_custom_from_server.rpc(String(channel), payload)
	_broadcasting_custom = false


func push_custom_to(peer_id: int, channel: StringName, data: Dictionary) -> void:
	if not is_server():
		return
	if not is_custom_channel_allowed(channel):
		return
	rpc_custom_from_server.rpc_id(peer_id, String(channel), data.duplicate(true))


func _ensure_hub_children() -> void:
	rooms = get_node_or_null("Rooms") as MpRoomDirectory
	if rooms == null:
		rooms = MpRoomDirectory.new()
		rooms.name = "Rooms"
		add_child(rooms)
	matchmaker = get_node_or_null("Matchmaker") as MpMatchmaker
	if matchmaker == null:
		matchmaker = MpMatchmaker.new()
		matchmaker.name = "Matchmaker"
		add_child(matchmaker)


func _enet_max_clients() -> int:
	if ids.dedicated:
		return maxi(1, max_players)
	return maxi(1, max_players - 1)


func _connected_player_count() -> int:
	var n := multiplayer.get_peers().size()
	if not ids.dedicated:
		n += 1
	return n


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if exceeds_max_players(_connected_player_count()):
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var slot := ids.assign_client(id)
	if slot == 0:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	rpc_assign_slot.rpc_id(id, slot)
	peer_joined.emit(id, slot)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_world_ready.erase(id)
	var slot := ids.unbind_peer(id)
	peer_left.emit(id, slot)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	leave()
	server_lost.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_assign_slot(slot: int) -> void:
	ids.local_slot = slot
	ids.bind(slot, multiplayer.get_unique_id())
	slot_assigned.emit(slot)


@rpc("authority", "call_remote", "reliable")
func rpc_load_world() -> void:
	load_world.emit()


@rpc("any_peer", "call_remote", "reliable")
func rpc_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	ids.assign_client(sender)
	if bool(_world_ready.get(sender, false)):
		return
	_world_ready[sender] = true
	client_world_ready.emit(sender)


@rpc("authority", "call_remote", "reliable")
func rpc_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)


@rpc("authority", "call_remote", "reliable")
func rpc_session_ended(data: Dictionary) -> void:
	session_ended.emit(data)


@rpc("any_peer", "call_remote", "reliable")
func rpc_custom_to_server(channel: String, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if ids.slot_for_peer(sender) == 0:
		return
	var name := StringName(channel)
	if not is_custom_channel_allowed(name):
		return
	custom_received.emit(name, data.duplicate(true), sender)


@rpc("authority", "call_remote", "reliable")
func rpc_custom_from_server(channel: String, data: Dictionary) -> void:
	var name := StringName(channel)
	if not is_custom_channel_allowed(name):
		return
	custom_received.emit(name, data.duplicate(true), 1)
