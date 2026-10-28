class_name OnlineNetwork
extends Node

## Where this game asks for online rooms: the issuer of `config` (data/net/online_config.tres: `issuer_url`, `game_id`). A child
## of the online screen. `apply()` points this process at that issuer (the flags `--issuer-url=` / `--issuer-game=` win, so a test
## reaches a local issuer without a localhost URL in the repo). Not: the room (MpOnline), the relay (the issuer names it), the rules of a match.

@export var config: MpNetConfig


func apply() -> void:
	if config == null:
		push_warning("OnlineNetwork: config is missing (data/net/online_config.tres)")
		return
	if not config.issuer_url.is_empty():
		MpIssuer.url = config.issuer_url
	if not config.game_id.is_empty():
		MpIssuer.game = config.game_id
	MpIssuer.from_flags()
