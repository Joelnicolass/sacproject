class_name OnlineNetwork
extends Node

## Where this game asks for online rooms. A child of the online screen. `apply()` points this
## process at the issuer of config.cfg (GameSettings: the URL and the game id). The flags
## `--issuer-url=` / `--issuer-game=` win, so a test reaches a local issuer. Not: the room
## (MpOnline), the relay (the issuer names it), the rules of a match.


func apply() -> void:
	var url := GameSettings.issuer_url()
	if not url.is_empty():
		MpIssuer.url = url
	var game := GameSettings.game_id()
	if not game.is_empty():
		MpIssuer.game = game
	MpIssuer.from_flags()
