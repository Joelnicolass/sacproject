class_name MpRoomServer
extends Node

## Put one in a scene and run that scene on your server (a VPS, or your PC for tests):
##   godot --headless --path . res://rooms.tscn
## It opens the online lobby (rooms, seats, ready, chat) and starts one dedicated match process per room that fills
## up; each match runs your normal project with `--dedicated` and a ticket, so only the seated players get in.
## Every number lives in `config` (a MpLobbyConfig .tres) and each one can be overridden by a flag with its name
## (`--lobby-port=7700`, `--max-matches=8`, `--transport=ws`). The rules of a room live in `rules`.
## It prints one line per event, so the log tells what happened. Not: the match's own rules (MpMatch, your game).

signal started(port: int)

@export var config: MpLobbyConfig
## The game's network .tres (the same one its MpFlow uses): the lobby and every match take transport, relay and TLS
## from it, so they always talk like the game. Empty = the flow's (its MpGame), or what `config` says without one.
@export var net_config: MpNetConfig
## Empty = the defaults (anything goes, 2 seats).
@export var rules: MpRoomRules
## Scene each match process opens. Empty = the game's boot scene (MpGame), or the project's main scene without one
## (the usual case: it holds the MpFlow).
@export_file("*.tscn") var match_scene: String = ""

var launcher: MpMatchLauncher


func _ready() -> void:
	## After the scene is set up: the lobby stack may have to be added under the root.
	_start.call_deferred()


func _start() -> void:
	var chosen := MpBoot.user_value("lobby-config", "")
	if not chosen.is_empty() and load(chosen) is MpLobbyConfig:
		config = load(chosen)
	if config == null:
		config = MpLobbyConfig.new()
	config = config.duplicate()
	## No net_config of its own: the game's (the flow that opened this scene with --room-server).
	var flow := MpFlow.find_in_tree(self)
	if net_config == null and flow:
		net_config = flow.net_config
	## A game in one .tres: each match opens the game's boot scene (its flow plays the ticket's match).
	if match_scene.is_empty() and flow and flow.game and not flow.game.boot_scene.is_empty():
		match_scene = flow.game.boot_scene
	if net_config:
		net_config.fill_lobby_config(config)
	launcher = MpMatchLauncher.new()
	launcher.name = "Launcher"
	launcher.config = config
	launcher.base_args = _base_args()
	## `--keep-match-files`: keep each match's folder (ticket, state, result and its log) to see what happened.
	launcher.keep_files = MpBoot.user_flag("keep-match-files")
	var extra := MpBoot.user_value("match-args", "")
	if not extra.is_empty():
		launcher.agent_args.append_array(extra.split(",", false))
	add_child(launcher)
	var lobby := MpLobbyLink.server(get_tree())
	(rules if rules else MpRoomRules.new()).bind(lobby)
	var err := lobby.start(launcher.config, launcher)
	if err != OK:
		push_error("MpRoomServer: lobby port %d: %s" % [launcher.config.lobby_port, error_string(err)])
		get_tree().quit(1)
		return
	lobby.rooms.match_assigned.connect(_on_match_assigned)
	lobby.rooms.room_error.connect(func(room_id: String, code: String) -> void:
		print("room \"%s\" error %s" % [lobby.name_of_room(room_id), code]))
	launcher.match_ended.connect(func(match_id: String, result: Dictionary) -> void:
		print("match %s ended %s" % [match_id, JSON.stringify(result)]))
	launcher.match_failed.connect(func(match_id: String, reason: String) -> void:
		print("match %s failed %s" % [match_id, reason]))
	## Ready means reachable (a relay accepts the lobby a moment after it starts).
	while not lobby.is_listening():
		if lobby.listen_refused():
			push_error("MpRoomServer: lobby port %d is in use on the relay (another room server of this game)" % launcher.config.lobby_port)
			get_tree().quit(1)
			return
		await get_tree().process_frame
	print("rooms ready port %d (%s)" % [launcher.config.lobby_port, launcher.config.transport])
	started.emit(launcher.config.lobby_port)


## Engine arguments of every match process: headless, the project folder when this is not an export, and
## `--match-engine-args=a,b` (tests).
func _base_args() -> PackedStringArray:
	var args := PackedStringArray(["--headless"])
	if not OS.has_feature("template"):
		args.append_array(PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]))
	if not match_scene.is_empty():
		args.append(match_scene)
	var engine_extra := MpBoot.user_value("match-engine-args", "")
	if not engine_extra.is_empty():
		args.append_array(engine_extra.split(",", false))
	return args


func _on_match_assigned(room_id: String, _session_id: String, port: int, _token: String) -> void:
	var lobby := MpLobbyLink.server(get_tree())
	print("match for room \"%s\" on port %d" % [lobby.name_of_room(room_id), port])
