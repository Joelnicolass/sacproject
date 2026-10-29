class_name MpRelayPeer
extends MultiplayerPeerExtension

## The "relay" transport: a MultiplayerPeer that goes through an MpKit relay (addons/mp_kit/relay/server.mjs) over
## WebSocket. The Godot server connects OUT to the relay as the host of a room, so it needs no public port (it can
## run behind NAT); players, web or desktop, connect to the same room. Same API, RPCs and replication as ENet / WS.
## Every MpKit "port" is a relay room: `<room_prefix>-<port>`, so the lobby (7700) and each match (7730…) are rooms.
## Not: the relay itself (Node), NAT punching, peer-to-peer.

const WELCOME := 1
const JOIN := 2
const LEAVE := 3
const DATA := 4
const KICK := 5

var _ws := WebSocketPeer.new()
var _host: bool = false
var _id: int = 0
var _status: ConnectionStatus = CONNECTION_DISCONNECTED
var _incoming: Array[Array] = []
var _current: Array = []
var _peers: Dictionary = {}
var _channel: int = 0
var _mode: int = TRANSFER_MODE_RELIABLE
var _target: int = 0
var _refuse: bool = false
var _welcomed: bool = false
## Host: the room may still hold a host that just died (its socket closes a moment later, a quick restart): a
## refused host tries again for REFUSED_GRACE_S (`--relay-refused-grace-s=` changes it) before it reports the room
## as in use. A launcher's matches use a short one: a new match has no earlier self to wait for.
const REFUSED_GRACE_S := 3.0
const REFUSED_RETRY_S := 0.3
var _url: String = ""
var _tls: TLSOptions
var _headers := PackedStringArray()
var _refused_until_ms: int = 0
var _retry_at_ms: int = 0


## `url` like wss://relay.example.com (or ws://127.0.0.1:8080); `room` the room name; `secret` only for the host of a
## server room; `token` (an issuer room, `p-<code>`): the one-time token for the host or a client.
func start(url: String, room: String, host: bool, secret: String = "", tls: TLSOptions = null, token: String = "") -> Error:
	_host = host
	var query := "?role=%s&room=%s" % ["host" if host else "client", room.uri_encode()]
	## A token expires within a minute and works once, so it may go in the URL: a browser host cannot set headers.
	if not token.is_empty():
		query += "&token=" + token.uri_encode()
	## The secret goes in a header, not the URL (URLs end up in access logs). Only the host of a server room sends it,
	## and that host is never a browser (a browser cannot set headers): a browser hosts issuer rooms, with a token.
	_headers = PackedStringArray(["X-Relay-Secret: " + secret]) if host and not secret.is_empty() else PackedStringArray()
	_url = url.trim_suffix("/") + "/" + query
	_tls = tls
	var grace := float(MpBoot.user_value("relay-refused-grace-s", str(REFUSED_GRACE_S)))
	_refused_until_ms = Time.get_ticks_msec() + int(maxf(grace, 0.0) * 1000.0)
	var err := _connect()
	if err != OK:
		_status = CONNECTION_DISCONNECTED
		return err
	## A host is the server (id 1) from the start, like an ENet server: nothing reaches it before clients join, and
	## clients join only after the relay accepted it. A client waits for its id (WELCOME).
	_id = 1 if host else 0
	_status = CONNECTION_CONNECTED if host else CONNECTION_CONNECTING
	return OK


## Relay close codes the kit acts on.
const CLOSE_ROOM_IN_USE := 4009
## What each relay close code means, for the log of a peer the relay closed.
## Host: peer id -> why it is being kicked (set_kick_reason).
var _kick_reasons: Dictionary = {}
const CLOSE_REASONS := {
	4004: "no host in this room (wrong relay_room or port, or the server is not up)",
	4005: "the host left the room",
	4006: "the room is full (RELAY_MAX_CLIENTS)",
	4007: "the host closed this client (the server turned it away: see admission_rejected)",
	4009: "the room has another live host",
	4010: "the host was silent too long",
}

## True when the relay refused this host because its room has a live host (a port in use: pick another), after the
## grace a quick restart needs.
func is_refused() -> bool:
	return _host and _retry_at_ms == 0 and _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED \
		and _ws.get_close_code() == CLOSE_ROOM_IN_USE


func _connect() -> Error:
	_ws = WebSocketPeer.new()
	_ws.handshake_headers = _headers
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	return _ws.connect_to_url(_url, _tls)


## True once the relay accepted this peer (WELCOME): a host is reachable by clients from then on.
func is_registered() -> bool:
	return _status == CONNECTION_CONNECTED and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and (not _host or _welcomed)


func _poll() -> void:
	if _retry_at_ms > 0:
		if Time.get_ticks_msec() < _retry_at_ms:
			return
		_retry_at_ms = 0
		_connect()
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if _host and not _welcomed and _ws.get_close_code() == CLOSE_ROOM_IN_USE and Time.get_ticks_msec() < _refused_until_ms:
			_retry_at_ms = Time.get_ticks_msec() + int(REFUSED_RETRY_S * 1000.0)
			return
		if _status != CONNECTION_DISCONNECTED:
			if _host and _ws.get_close_code() == CLOSE_ROOM_IN_USE:
				push_warning("MpRelayPeer: the relay room is in use by another host (like a port in use)")
			elif _host:
				push_error("MpRelayPeer: the relay closed the host (%d %s)" % [_ws.get_close_code(), _ws.get_close_reason()])
			else:
				var code := _ws.get_close_code()
				var why := _ws.get_close_reason()
				push_warning("MpRelayPeer: the relay closed this client (%d): %s%s" % [code, CLOSE_REASONS.get(code, why),
					": " + why if code in CLOSE_REASONS and not why.is_empty() else ""])
			_drop_all()
		return
	while _ws.get_available_packet_count() > 0:
		_read(_ws.get_packet())


func _read(msg: PackedByteArray) -> void:
	if msg.size() < 5:
		return
	var kind := msg[0]
	var value := msg.decode_u32(1)
	match kind:
		WELCOME:
			_welcomed = true
			_id = value
			_status = CONNECTION_CONNECTED
			if not _host:
				_peers[1] = true
				peer_connected.emit(1)
		JOIN:
			if _host and not _refuse:
				_peers[value] = true
				peer_connected.emit(value)
		LEAVE:
			if _peers.erase(value):
				peer_disconnected.emit(value)
		DATA:
			if _host and not _peers.has(value):
				return
			if msg.size() >= 7:
				_incoming.append([value, msg[5], msg[6], msg.slice(7)])


func _drop_all() -> void:
	_status = CONNECTION_DISCONNECTED
	for peer_id in _peers.keys():
		peer_disconnected.emit(peer_id)
	_peers.clear()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	var msg := PackedByteArray()
	msg.resize(7)
	msg[0] = DATA
	msg.encode_s32(1, _target if _host else 1)
	msg[5] = _channel
	msg[6] = _mode
	msg.append_array(buffer)
	return _ws.send(msg)


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	_current = _incoming.pop_front()
	return _current[3]


func _get_packet_peer() -> int:
	return int(_incoming[0][0]) if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_incoming[0][1]) if not _incoming.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return (int(_incoming[0][2]) if not _incoming.is_empty() else TRANSFER_MODE_RELIABLE) as TransferMode


func _get_max_packet_size() -> int:
	return 1 << 18


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode as TransferMode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _is_server() -> bool:
	return _host


func _get_unique_id() -> int:
	return _id


func _get_connection_status() -> ConnectionStatus:
	return _status


func _close() -> void:
	_retry_at_ms = 0
	_refused_until_ms = 0
	_ws.close()
	_drop_all()


## The host closes a client: the relay closes its socket (KICK) and its packets are dropped from now on.
## Host: why the next close of `peer` happens; the relay passes it to the client as the close reason.
func set_kick_reason(peer: int, reason: String) -> void:
	_kick_reasons[peer] = reason


func _disconnect_peer(peer: int, _force: bool) -> void:
	var msg := PackedByteArray()
	msg.resize(5)
	msg[0] = KICK
	msg.encode_u32(1, peer)
	## The reason after the id (old relays read only the id). A WebSocket close reason fits 123 bytes.
	msg.append_array(str(_kick_reasons.get(peer, "")).to_utf8_buffer().slice(0, 100))
	_kick_reasons.erase(peer)
	_ws.send(msg)
	if _peers.erase(peer):
		peer_disconnected.emit(peer)


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _is_server_relay_supported() -> bool:
	return false
