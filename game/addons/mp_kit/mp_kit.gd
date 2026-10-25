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
## Client side: the server refused the ticket (reason is opaque, chosen by the server).
signal admission_rejected(reason: String)
## Opaque Dictionary pipe. Kit does not interpret `data`. from_peer is 1 when the server pushed.
signal custom_received(channel: StringName, data: Dictionary, from_peer: int)

var port: int = 7777
var max_players: int = 2
## Empty = every channel. Non-empty = drop unknown names (controlled low-level).
var custom_channels: PackedStringArray = PackedStringArray()
var ids: MpIds = MpIds.new()
## Server side. Empty = legacy behavior (slot by connection order, no ticket).
## Set = every new peer must present a ticket before it gets a slot:
## `admission.call(peer_id: int, ticket: String) -> int` returns the slot, or 0 to reject.
var admission: Callable = Callable()
## Seconds a new peer may stay without presenting a ticket (only with `admission` set).
var admission_timeout_s: float = 5.0
## Tickets longer than this are rejected without reaching `admission`.
const TICKET_MAX_LEN := 512
## Seconds between the rejection RPC and the disconnect.
const REJECT_FLUSH_S := 0.2
## Peers that may wait for admission at once; more are disconnected on arrival (a flood of empty connections).
var max_pending_admission: int = 64
## Largest Dictionary a client may send through the custom tunnel (var_to_bytes), and how often.
var custom_max_bytes: int = 8192
var custom_limit := MpRateLimit.new(30.0, 60.0)
var rooms: MpRoomDirectory
var matchmaker: MpMatchmaker

## `MpTransport.ENET` (default) or `MpTransport.WS`. Read from `--transport=` at startup; glue may set it
## before `host()` / `join()`. Same API and RPCs with both.
var transport: String = MpTransport.ENET
## WebSocket TLS (wss://). Server: certificate + key; client: TLSOptions.client(). Null = plain. MpNetConfig sets them.
var tls_server: TLSOptions
var tls_client: TLSOptions
var _peer: MultiplayerPeer
var _world_ready: Dictionary = {}
var _broadcasting_custom: bool = false
var _pending_ticket: String = ""
var _awaiting_ticket: Dictionary = {}


func _ready() -> void:
	## Infrastructure: the session (admission timers, rejections) keeps going while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	transport = MpTransport.from_flags()
	tls_server = MpTransport.server_tls_from_flags()
	tls_client = MpTransport.client_tls_from_flags()
	_ensure_hub_children()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
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


## Server: clients can reach it now. ENet / WebSocket: as soon as it hosts; relay: once the relay accepted it.
func is_listening() -> bool:
	return is_server() and MpTransport.is_listening(_peer)


func is_listen_host() -> bool:
	return is_server() and not ids.dedicated


## True where the game rules run: solo (no network) or the server. Use it instead of
## `not is_networked() or is_server()`.
func is_authority() -> bool:
	return not is_networked() or is_server()


## The slot of the player on this machine; 0 on a dedicated server and on a client that has not got one yet.
func local_slot() -> int:
	if not is_networked():
		return ids.host_slot
	if multiplayer.is_server():
		if ids.dedicated:
			return 0
		return ids.host_slot
	return ids.local_slot


## True when this machine has a player with a known slot (solo, a listen host, a client once the server assigned it).
func has_local_slot() -> bool:
	return local_slot() > 0


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
	var made := MpTransport.create_server(transport, port, _enet_max_clients(), tls_server)
	var peer := made["peer"] as MultiplayerPeer
	if int(made["error"]) != OK:
		ids.dedicated = false
		return int(made["error"]) as Error
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


## `p_port` <= 0 uses `port`. A non-empty `ticket` is presented to the server on connect.
func join(address: String, p_port: int = -1, ticket: String = "") -> Error:
	leave()
	var made := MpTransport.create_client(transport, address, p_port if p_port > 0 else port, tls_client)
	var peer := made["peer"] as MultiplayerPeer
	if int(made["error"]) != OK:
		return int(made["error"]) as Error
	_peer = peer
	multiplayer.multiplayer_peer = peer
	ids.reset_offline()
	ids.local_slot = 0
	_world_ready.clear()
	_pending_ticket = ticket
	return OK


func leave() -> void:
	if rooms:
		rooms.reset()
	if matchmaker:
		matchmaker.reset()
	_world_ready.clear()
	_awaiting_ticket.clear()
	_pending_ticket = ""
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
	for peer_id in _broadcast_peers():
		rpc_snapshot.rpc_id(peer_id, data)


func push_snapshot_to(peer_id: int, data: Dictionary) -> void:
	if not is_server():
		return
	rpc_snapshot.rpc_id(peer_id, data)


## Peers reload the world: their world_ready (and spawner reveals) start over.
func broadcast_load_world() -> void:
	if not is_server():
		return
	_world_ready.clear()
	for peer_id in _broadcast_peers():
		rpc_load_world.rpc_id(peer_id)


func load_world_to(peer_id: int) -> void:
	if not is_server():
		return
	_world_ready.erase(peer_id)
	rpc_load_world.rpc_id(peer_id)


func broadcast_session_ended(data: Dictionary) -> void:
	if not is_server():
		return
	for peer_id in _broadcast_peers():
		rpc_session_ended.rpc_id(peer_id, data)


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
	for peer_id in _broadcast_peers():
		rpc_custom_from_server.rpc_id(peer_id, String(channel), payload)
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


## Peers that may receive broadcasts. With `admission` set, only those that already have a slot.
func _broadcast_peers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for peer_id in multiplayer.get_peers():
		if not admission.is_valid() or ids.slot_for_peer(peer_id) != 0:
			out.append(peer_id)
	return out


func _enet_max_clients() -> int:
	if ids.dedicated:
		return maxi(1, max_players)
	return maxi(1, max_players - 1)


func _connected_player_count() -> int:
	var n := multiplayer.get_peers().size()
	if admission.is_valid():
		n = ids.occupied_slots().size()
	if not ids.dedicated:
		n += 1
	return n


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if admission.is_valid():
		if _awaiting_ticket.size() >= max_pending_admission:
			multiplayer.multiplayer_peer.disconnect_peer(id)
			return
		_awaiting_ticket[id] = true
		get_tree().create_timer(admission_timeout_s).timeout.connect(_on_admission_timeout.bind(id))
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
	if _awaiting_ticket.erase(id):
		return
	_world_ready.erase(id)
	custom_limit.forget(id)
	var slot := ids.unbind_peer(id)
	if slot == 0 and admission.is_valid():
		return
	peer_left.emit(id, slot)


func _on_admission_timeout(id: int) -> void:
	if _awaiting_ticket.has(id):
		_reject_peer(id, "timeout")


## Server side: tells `id` why it is turned away and disconnects it (the glue judged something the kit cannot, e.g. an invalid pick).
func reject_peer(id: int, reason: String) -> void:
	_reject_peer(id, reason)


func _reject_peer(id: int, reason: String) -> void:
	_awaiting_ticket.erase(id)
	if not is_server():
		return
	rpc_admission_rejected.rpc_id(id, reason)
	## Let the reliable RPC leave before the disconnect command.
	var closing := multiplayer.multiplayer_peer
	get_tree().create_timer(REJECT_FLUSH_S).timeout.connect(func() -> void:
		if closing != null and multiplayer.multiplayer_peer == closing and multiplayer.get_peers().has(id):
			closing.disconnect_peer(id))


func _on_connected_to_server() -> void:
	if not _pending_ticket.is_empty():
		rpc_present_ticket.rpc_id(1, _pending_ticket)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	if _peer == null:
		return
	## Dropped while still waiting for a slot: a rejection whose RPC did not arrive.
	if not _pending_ticket.is_empty() and ids.local_slot == 0:
		leave()
		admission_rejected.emit("dropped")
		return
	leave()
	server_lost.emit()


@rpc("authority", "call_remote", "reliable")
func rpc_assign_slot(slot: int) -> void:
	ids.local_slot = slot
	ids.bind(slot, multiplayer.get_unique_id())
	slot_assigned.emit(slot)


@rpc("any_peer", "call_remote", "reliable")
func rpc_present_ticket(ticket: String) -> void:
	if not multiplayer.is_server() or not admission.is_valid():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _awaiting_ticket.has(sender):
		return
	if ticket.length() > TICKET_MAX_LEN:
		_reject_peer(sender, "rejected")
		return
	var slot := int(admission.call(sender, ticket))
	if slot <= 0:
		_reject_peer(sender, "rejected")
		return
	if slot < ids.first_client_slot() or slot > ids.max_players:
		_reject_peer(sender, "slot_out_of_range")
		return
	if not ids.bind_client(sender, slot):
		_reject_peer(sender, "slot_taken")
		return
	_awaiting_ticket.erase(sender)
	rpc_assign_slot.rpc_id(sender, slot)
	peer_joined.emit(sender, slot)


@rpc("authority", "call_remote", "reliable")
func rpc_admission_rejected(reason: String) -> void:
	leave()
	admission_rejected.emit(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_load_world() -> void:
	load_world.emit()


@rpc("any_peer", "call_remote", "reliable")
func rpc_world_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if admission.is_valid():
		if ids.slot_for_peer(sender) == 0:
			return
	else:
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
	if var_to_bytes(data).size() > custom_max_bytes or not custom_limit.allow(sender):
		return
	custom_received.emit(name, data.duplicate(true), sender)


@rpc("authority", "call_remote", "reliable")
func rpc_custom_from_server(channel: String, data: Dictionary) -> void:
	var name := StringName(channel)
	if not is_custom_channel_allowed(name):
		return
	custom_received.emit(name, data.duplicate(true), 1)
