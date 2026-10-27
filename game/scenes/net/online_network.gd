class_name OnlineNetwork
extends Node

## Where this game asks for online rooms: the issuer of `config` (data/net/online_config.tres: `issuer_url`, `game_id`). A child
## of the online screen. `apply()` points this process at that issuer (the flags `--issuer-url=` / `--issuer-game=` win, so a test
## reaches a local issuer without a localhost URL in the repo); `restore()` gives LAN and «Servidor local» the transport of the
## flags back when the player leaves the screen. Not: the room (MpOnline), the relay (the issuer names it), the rules of a match.

@export var config: MpNetConfig


func apply() -> void:
	if config == null:
		push_warning("OnlineNetwork: falta config (data/net/online_config.tres)")
		return
	if not config.issuer_url.is_empty():
		MpIssuer.url = config.issuer_url
	if not config.game_id.is_empty():
		MpIssuer.game = config.game_id
	MpIssuer.from_flags()


## WORKAROUND: MpKit 0.18.0 leaves MpKit.transport on the relay after an online room (asked to the kit session: the one
## that changed it gives it back). Until then the screen does it on its way out.
func restore() -> void:
	MpKit.transport = MpTransport.from_flags()
