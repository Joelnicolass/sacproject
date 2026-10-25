class_name MpTransport
extends RefCounted

## Network transport of the kit: ENet (UDP, the default) or WebSocket (TCP, needed by a web export and by TCP
## tunnels). Only builds the `MultiplayerPeer`; RPCs, slots and replication do not change with it.
## The names are the values of `--transport=enet|ws` and of `MpLobbyConfig.transport`.
## `wss://` (TLS): pass `TLSOptions` to `create_server` / `create_client`, or terminate TLS in a reverse proxy
## (see the README). `--net-lag-ms` / `--net-jitter-ms` / `--net-loss` wrap the peer in MpLagPeer (tests only).

const ENET := "enet"
const WS := "ws"


## `--transport=` flag; an unknown value falls back to ENet with a warning.
static func from_flags(default: String = ENET) -> String:
	return normalize(MpBoot.user_value("transport", default))


static func normalize(name: String) -> String:
	var low := name.strip_edges().to_lower()
	if low == WS or low == "websocket" or low == "wss":
		return WS
	if low.is_empty() or low == ENET or low == "udp":
		return ENET
	push_warning("--transport=%s: unknown, ENet is used" % name)
	return ENET


## `{error, peer}`. `max_clients` only applies to ENet (the WebSocket peer has no cap of its own).
static func create_server(kind: String, port: int, max_clients: int, tls: TLSOptions = null) -> Dictionary:
	if normalize(kind) == WS:
		var ws := WebSocketMultiplayerPeer.new()
		var err_ws := ws.create_server(port, "*", tls)
		return {"error": err_ws, "peer": MpLagPeer.wrap_from_flags(ws)}
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, max_clients)
	return {"error": err, "peer": MpLagPeer.wrap_from_flags(enet)}


## `{error, peer}`. WebSocket builds `ws://host:port` (or `wss://` with `tls`); a `host` that already has a
## scheme (`wss://play.example.com/x`) is used as is.
static func create_client(kind: String, host: String, port: int, tls: TLSOptions = null) -> Dictionary:
	if normalize(kind) == WS:
		var ws := WebSocketMultiplayerPeer.new()
		var scheme := "wss" if tls != null else "ws"
		var url := host if host.contains("://") else "%s://%s:%d" % [scheme, host, port]
		var err_ws := ws.create_client(url, tls)
		return {"error": err_ws, "peer": MpLagPeer.wrap_from_flags(ws)}
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(host, port)
	return {"error": err, "peer": MpLagPeer.wrap_from_flags(enet)}


## True if `port` can be opened on this machine with `kind` (a probe that opens and closes it).
static func port_is_free(kind: String, port: int) -> bool:
	if normalize(kind) == WS:
		var tcp := TCPServer.new()
		var err_tcp := tcp.listen(port)
		tcp.stop()
		return err_tcp == OK
	var udp := UDPServer.new()
	var err := udp.listen(port)
	udp.stop()
	return err == OK
