class_name MpTransport
extends RefCounted

## Network transport of the kit: ENet (UDP, the default), WebSocket (TCP, needed by a web export) or relay (WebSocket
## through an MpKit relay, addons/mp_kit/relay: the server connects out, so it needs no public port; web and desktop).
## Only builds the `MultiplayerPeer`; RPCs, slots and replication do not change with it.
## The names are the values of `--transport=enet|ws|relay` and of `MpLobbyConfig.transport`.
## Relay settings: `relay_url` (wss://…), `relay_room` (room prefix; each port is the room `<prefix>-<port>`) from
## `--relay-url=` / `--relay-room=` or an MpNetConfig / MpLobbyConfig; the host secret from `--relay-secret=` or the
## MPKIT_RELAY_SECRET environment variable (never in a .tres the clients get).
## `wss://` (TLS): pass `TLSOptions` to `create_server` / `create_client`, or terminate TLS in a reverse proxy
## (see the README). `--net-lag-ms` / `--net-jitter-ms` / `--net-loss` wrap the peer in MpLagPeer (tests only).

const ENET := "enet"
const WS := "ws"
const RELAY := "relay"

static var relay_url: String = ""
static var relay_room: String = "mpkit"
static var _relay_read: bool = false


## The relay settings from the flags and the environment (once); a config may override them afterwards.
static func relay_from_flags() -> void:
	if _relay_read:
		return
	_relay_read = true
	## An empty flag (a room server forwards its empty fields) leaves the setting as it is.
	var url := MpBoot.user_value("relay-url", "")
	var room := MpBoot.user_value("relay-room", "")
	if not url.is_empty():
		relay_url = url
	if not room.is_empty():
		relay_room = room


static func relay_secret() -> String:
	var flag := MpBoot.user_value("relay-secret", "")
	return flag if not flag.is_empty() else OS.get_environment("MPKIT_RELAY_SECRET")


## The relay room of a kit "port".
static func relay_room_for(port: int) -> String:
	relay_from_flags()
	return "%s-%d" % [relay_room, port]


## `--transport=` flag; an unknown value falls back to ENet with a warning. A web export is WebSocket or relay.
static func from_flags(default: String = ENET) -> String:
	var chosen := normalize(MpBoot.user_value("transport", default))
	if OS.has_feature("web") and chosen == ENET:
		return WS
	return chosen


static func normalize(name: String) -> String:
	var low := name.strip_edges().to_lower()
	if low == WS or low == "websocket" or low == "wss":
		return WS
	if low == RELAY or low == "tunnel":
		return RELAY
	if low.is_empty() or low == ENET or low == "udp":
		return ENET
	push_warning("--transport=%s: unknown, ENet is used" % name)
	return ENET


## Server TLS from two files (PEM certificate and key), or null when either path is empty. ENet ignores it.
static func server_tls(certificate_path: String, key_path: String) -> TLSOptions:
	if certificate_path.is_empty() or key_path.is_empty():
		return null
	var cert := X509Certificate.new()
	var key := CryptoKey.new()
	if cert.load(certificate_path) != OK or key.load(key_path) != OK:
		push_error("MpTransport: cannot load TLS certificate %s / key %s" % [certificate_path, key_path])
		return null
	return TLSOptions.server(key, cert)


## `--tls-certificate-path=` + `--tls-key-path=`: the server speaks wss:// (a VPS, a room server and its matches).
static func server_tls_from_flags() -> TLSOptions:
	return server_tls(MpBoot.user_value("tls-certificate-path", ""), MpBoot.user_value("tls-key-path", ""))


## `--tls-client`: the client speaks wss://. `--tls-trusted-ca=` (a PEM file, for a private CA or a self-signed
## certificate; empty = the system's CAs) and `--tls-common-name=` (the name the certificate was issued for).
static func client_tls_from_flags() -> TLSOptions:
	if not MpBoot.user_flag("tls-client"):
		return null
	var ca: X509Certificate = null
	var ca_path := MpBoot.user_value("tls-trusted-ca", "")
	if not ca_path.is_empty():
		ca = X509Certificate.new()
		if ca.load(ca_path) != OK:
			push_error("MpTransport: cannot load TLS CA %s" % ca_path)
			ca = null
	return TLSOptions.client(ca, MpBoot.user_value("tls-common-name", ""))


## `{error, peer}`. `max_clients` only applies to ENet (the WebSocket peer has no cap of its own).
static func create_server(kind: String, port: int, max_clients: int, tls: TLSOptions = null) -> Dictionary:
	if normalize(kind) == RELAY:
		## The host is a client of the relay: the client TLS flags apply to it (null = the system's CAs).
		return _relay(relay_room_for(port), true, "", client_tls_from_flags())
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
	if normalize(kind) == RELAY:
		## A full URL as the host is the relay itself (a link someone shared); otherwise the configured relay.
		return _relay(relay_room_for(port), false, host if host.contains("://") else "", tls)
	if normalize(kind) == WS:
		var ws := WebSocketMultiplayerPeer.new()
		var scheme := "wss" if tls != null else "ws"
		var url := host if host.contains("://") else "%s://%s:%d" % [scheme, host, port]
		var err_ws := ws.create_client(url, tls)
		return {"error": err_ws, "peer": MpLagPeer.wrap_from_flags(ws)}
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(host, port)
	return {"error": err, "peer": MpLagPeer.wrap_from_flags(enet)}


static func _relay(room: String, host: bool, url_override: String, tls: TLSOptions = null) -> Dictionary:
	relay_from_flags()
	var url := url_override if not url_override.is_empty() else relay_url
	if url.is_empty():
		push_error("MpTransport: the relay transport needs a relay URL (--relay-url=wss://… or MpNetConfig.relay_url)")
		return {"error": ERR_UNCONFIGURED, "peer": null}
	var peer := MpRelayPeer.new()
	var err := peer.start(url, room, host, relay_secret() if host else "", tls)
	return {"error": err, "peer": MpLagPeer.wrap_from_flags(peer)}


## A server peer clients can reach now: ENet / WebSocket as soon as it is up; relay once the relay accepted the host.
static func is_listening(peer: MultiplayerPeer) -> bool:
	while peer is MpLagPeer:
		peer = (peer as MpLagPeer).inner()
	if peer == null:
		return false
	if peer is MpRelayPeer:
		return (peer as MpRelayPeer).is_registered()
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## A server peer the relay turned away because its room (its port) has a live host already. ENet / WebSocket
## learn a busy port when they open it; the relay tells it a moment later.
static func is_refused(peer: MultiplayerPeer) -> bool:
	while peer is MpLagPeer:
		peer = (peer as MpLagPeer).inner()
	return peer is MpRelayPeer and (peer as MpRelayPeer).is_refused()


## True if `port` can be opened on this machine with `kind` (a probe that opens and closes it).
static func port_is_free(kind: String, port: int) -> bool:
	if normalize(kind) == RELAY:
		return true
	if normalize(kind) == WS:
		var tcp := TCPServer.new()
		var err_tcp := tcp.listen(port)
		tcp.stop()
		return err_tcp == OK
	var udp := UDPServer.new()
	var err := udp.listen(port)
	udp.stop()
	return err == OK
