class_name MpLagPeer
extends MultiplayerPeerExtension

## A bad network on purpose, to test how a game feels: wraps the real peer (ENet or WebSocket) and holds every packet
## this process sends for `lag_ms` (+ up to `jitter_ms`), and drops unreliable ones with `loss` probability.
## Reliable packets are never dropped and keep their order. Only for tests and tuning: never in a release.
## Turn it on with flags on each process: `--net-lag-ms=100 --net-jitter-ms=30 --net-loss=0.05` (one way, outgoing).

var lag_ms: float = 0.0
var jitter_ms: float = 0.0
var loss: float = 0.0

var _inner: MultiplayerPeer
var _out: Array[Dictionary] = []
var _last_ordered_due: float = 0.0
var _channel: int = 0
var _mode: int = TRANSFER_MODE_RELIABLE
var _target: int = 0
var _rng := RandomNumberGenerator.new()


## `peer` wrapped when a lag flag is set; `peer` itself otherwise.
static func wrap_from_flags(peer: MultiplayerPeer) -> MultiplayerPeer:
	var lag := float(MpBoot.user_value("net-lag-ms", "0"))
	var jitter := float(MpBoot.user_value("net-jitter-ms", "0"))
	var drop := float(MpBoot.user_value("net-loss", "0"))
	if peer == null or (lag <= 0.0 and jitter <= 0.0 and drop <= 0.0):
		return peer
	var lagged := MpLagPeer.new()
	lagged.setup(peer, lag, jitter, drop)
	print("MpLagPeer: %d ms + %d ms jitter, %d%% loss" % [lag, jitter, roundi(drop * 100.0)])
	return lagged


## The real peer under the simulated lag.
func inner() -> MultiplayerPeer:
	return _inner


func setup(p_inner: MultiplayerPeer, p_lag_ms: float, p_jitter_ms: float, p_loss: float) -> void:
	_inner = p_inner
	lag_ms = maxf(p_lag_ms, 0.0)
	jitter_ms = maxf(p_jitter_ms, 0.0)
	loss = clampf(p_loss, 0.0, 1.0)
	_inner.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	_inner.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))


func _put_packet_script(buffer: PackedByteArray) -> Error:
	var unreliable := _mode != TRANSFER_MODE_RELIABLE
	if unreliable and _rng.randf() < loss:
		return OK
	var due := Time.get_ticks_msec() + lag_ms + _rng.randf() * jitter_ms
	if not unreliable or _mode == TRANSFER_MODE_UNRELIABLE_ORDERED:
		## Ordered packets never overtake each other.
		due = maxf(due, _last_ordered_due)
		_last_ordered_due = due
	_out.append({"data": buffer, "channel": _channel, "mode": _mode, "target": _target, "due": due})
	return OK


func _poll() -> void:
	var now := Time.get_ticks_msec()
	var keep: Array[Dictionary] = []
	for packet in _out:
		if float(packet["due"]) > now:
			keep.append(packet)
			continue
		_inner.transfer_channel = int(packet["channel"])
		_inner.transfer_mode = int(packet["mode"]) as TransferMode
		_inner.set_target_peer(int(packet["target"]))
		_inner.put_packet(packet["data"])
	_out = keep
	_inner.poll()


func _get_available_packet_count() -> int:
	return _inner.get_available_packet_count()


func _get_packet_script() -> PackedByteArray:
	return _inner.get_packet()


func _get_packet_peer() -> int:
	return _inner.get_packet_peer()


func _get_packet_channel() -> int:
	return _inner.get_packet_channel()


func _get_packet_mode() -> TransferMode:
	return _inner.get_packet_mode()


func _get_max_packet_size() -> int:
	return 1 << 24


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
	return _inner.get_unique_id() == 1


func _get_unique_id() -> int:
	return _inner.get_unique_id()


func _get_connection_status() -> ConnectionStatus:
	return _inner.get_connection_status()


func _close() -> void:
	_out.clear()
	_inner.close()


func _disconnect_peer(peer: int, force: bool) -> void:
	_inner.disconnect_peer(peer, force)


## The relay's kick reason, passed to the wrapped peer (MpRelayPeer.set_kick_reason).
func set_kick_reason(peer: int, reason: String) -> void:
	if _inner.has_method(&"set_kick_reason"):
		_inner.call(&"set_kick_reason", peer, reason)


func _set_refuse_new_connections(enable: bool) -> void:
	_inner.refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return _inner.refuse_new_connections


func _is_server_relay_supported() -> bool:
	return _inner.is_server_relay_supported()
