class_name OnlineNetwork
extends Node

## How the online rooms are reached: the network of `config` (data/net/online_config.tres: the relay). A child of the
## lobby screen; only `apply()` changes the process, so solo, LAN and «Servidor local» keep the ENet of the flags and
## `restore()` gives it back when the player leaves the rooms. Flags win over the resource (`--transport=enet` with
## `--lobby=host:port` reaches a local room server; `--relay-url` / `--relay-room` aim at another relay).
## A relay needs no secret on a client. Ref: RFC-034 (online by relay).

@export var config: MpNetConfig


## The lobby link and the match that follows it (MpKit.join) talk through the same transport.
func apply() -> void:
	if config == null:
		return
	MpTransport.relay_from_flags()
	if MpBoot.user_value("relay-url", "").is_empty() and not config.relay_url.is_empty():
		MpTransport.relay_url = config.relay_url
	if MpBoot.user_value("relay-room", "").is_empty() and not config.relay_room.is_empty():
		MpTransport.relay_room = config.relay_room
	var chosen := config.effective_transport()
	MpLobby.client.transport = chosen
	MpKit.transport = chosen
	var tls := config.client_tls()
	if tls:
		MpLobby.client.tls = tls
		MpKit.tls_client = tls


## Back to the menu: LAN and «Servidor local» use the transport of the flags again.
func restore() -> void:
	MpKit.transport = MpTransport.from_flags()
