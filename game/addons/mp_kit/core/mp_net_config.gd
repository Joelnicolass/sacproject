class_name MpNetConfig
extends Resource

## Every network setting of a game in one .tres: transport, port, players, the public address, TLS and the relay.
## Assign the same .tres to MpFlow and, for online rooms, to MpRoomServer (and its matches use it through the
## project's MpFlow); flags still win (`--transport=ws`, `--mp-port=N`). Not: room or match rules.
## A web export always uses WebSocket and never hosts or browses the LAN (a browser can do neither): one setting less
## to get wrong. Web and desktop do not mix: a WebSocket server only talks to WebSocket clients.

## enet = UDP (desktop, lowest latency). ws = WebSocket over TCP (web builds). relay = WebSocket through an MpKit
## relay (addons/mp_kit/relay): the server connects out, so it needs no public port (Railway, a PC behind NAT…).
@export_enum("enet", "ws", "relay") var transport: String = "enet"
@export_range(1, 65535) var port: int = 7777
@export_range(1, 256) var max_players: int = 4
## Where clients find the server online ("play.example.com", "203.0.113.5:7777"): the boot menu's Join field and the
## lobby screen start with it. Empty = 127.0.0.1. Web clients usually need a domain with TLS (`wss://`).
@export var public_host: String = ""
## Names the Dictionary tunnel accepts (empty = any).
@export var custom_channels: PackedStringArray = PackedStringArray()
@export var lan_discovery: bool = true

@export_group("Relay")
## The relay's address (wss://your-relay.up.railway.app). The host's secret is never here: the server gets it from
## MPKIT_RELAY_SECRET or --relay-secret.
@export var relay_url: String = ""
## Room prefix on the relay: each port is the room `<prefix>-<port>`. Use your game's name.
@export var relay_room: String = "mpkit"

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


## `--max-players=N` on a server process wins over the .tres (one build, several server sizes).
func effective_max_players() -> int:
	return int(MpBoot.user_value("max-players", str(max_players)))


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


## Copies the network part of this .tres (transport, relay, TLS files) into a room server / match launcher config,
## so the lobby and every match talk like the game. Fields already set in `config` win (and flags win over both).
## `config` is an MpLobbyConfig, untyped on purpose: this .tres (used by MpFlow) must not load the lobby scripts.
func fill_lobby_config(config: Resource) -> void:
	if MpBoot.user_value("transport", "").is_empty():
		config.set("transport", transport)
	if str(config.get("relay_url")).is_empty():
		config.set("relay_url", relay_url)
	if str(config.get("relay_room")).is_empty():
		config.set("relay_room", relay_room)
	if str(config.get("tls_certificate_path")).is_empty() and tls_certificate and tls_key:
		config.set("tls_certificate_path", ProjectSettings.globalize_path(tls_certificate.resource_path))
		config.set("tls_key_path", ProjectSettings.globalize_path(tls_key.resource_path))


## Puts these settings on MpKit (before host / join).
func apply(host_slot: int = 1) -> void:
	MpKit.configure(effective_port(), effective_max_players(), host_slot, custom_channels)
	MpKit.transport = effective_transport()
	MpTransport.relay_from_flags()
	if not relay_url.is_empty() and MpBoot.user_value("relay-url", "").is_empty():
		MpTransport.relay_url = relay_url
	if MpBoot.user_value("relay-room", "").is_empty() and not relay_room.is_empty():
		MpTransport.relay_room = relay_room
	## What this .tres sets wins; otherwise the TLS flags MpKit read at startup stay.
	var server := server_tls()
	if server:
		MpKit.tls_server = server
	var client := client_tls()
	if client:
		MpKit.tls_client = client
