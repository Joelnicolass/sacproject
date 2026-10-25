class_name MpNetConfig
extends Resource

## Every network setting of a game in one .tres: transport, port, players, the public address and TLS. Assign it to
## MpFlow (and the room server); flags still win (`--transport=ws`, `--mp-port=N`). Not: room or match rules.
## A web export always uses WebSocket and never hosts or browses the LAN (a browser can do neither): one setting less
## to get wrong. Web and desktop do not mix: a WebSocket server only talks to WebSocket clients.

## enet = UDP (desktop, lowest latency). ws = WebSocket over TCP (web builds, TCP tunnels).
@export_enum("enet", "ws") var transport: String = "enet"
@export_range(1, 65535) var port: int = 7777
@export_range(1, 256) var max_players: int = 4
## Where clients find the server online (a domain or IP). Empty = they type it. Web clients usually need a domain
## with TLS (`wss://`), because a page served over https may not open plain `ws://`.
@export var public_host: String = ""
## Names the Dictionary tunnel accepts (empty = any).
@export var custom_channels: PackedStringArray = PackedStringArray()
@export var lan_discovery: bool = true

@export_group("TLS (wss://)")
## Server side: certificate and key. Both set = the WebSocket server speaks wss:// itself (no reverse proxy).
@export var tls_certificate: X509Certificate
@export var tls_key: CryptoKey
## Client side: on = wss://. Leave `tls_trusted_ca` empty for a normal certificate (the system's CAs).
@export var tls_client: bool = false
@export var tls_trusted_ca: X509Certificate
## The name the server's certificate was issued for, when it is not the address clients type. Empty = that address.
@export var tls_common_name: String = ""


## The transport this build really uses: WebSocket on the web, the flag or this setting elsewhere.
func effective_transport() -> String:
	if OS.has_feature("web"):
		return MpTransport.WS
	return MpTransport.from_flags(transport)


func effective_port() -> int:
	return int(MpBoot.user_value("mp-port", str(port)))


## A browser cannot open a server or listen for LAN rooms.
static func can_host() -> bool:
	return not OS.has_feature("web")


func server_tls() -> TLSOptions:
	if tls_certificate and tls_key:
		return TLSOptions.server(tls_key, tls_certificate)
	return null


func client_tls() -> TLSOptions:
	if not tls_client:
		return null
	return TLSOptions.client(tls_trusted_ca, tls_common_name)


## Puts these settings on MpKit (before host / join).
func apply(host_slot: int = 1) -> void:
	MpKit.configure(effective_port(), max_players, host_slot, custom_channels)
	MpKit.transport = effective_transport()
	## What this .tres sets wins; otherwise the TLS flags MpKit read at startup stay.
	var server := server_tls()
	if server:
		MpKit.tls_server = server
	var client := client_tls()
	if client:
		MpKit.tls_client = client
