extends Node

## The scene the VPS runs (and the tests, with a local config):
## `godot --headless --path game res://scenes/net/room_server.tscn -- --room-server [--lobby-config=res://…tres] [--max-matches=2]`
## (or, as in an export, without the scene: the boot sends a `--room-server` process here)
## It puts the kit's pieces together: the launcher (one dedicated process per match), the rules of Sacrifice
## (picks, options, ticket) and the lobby server. Every number is a flag of `MpLobbyConfig` (`--lobby-port=7700`, …).
## It prints one line per event so a log tells the story: `salas listo puerto N`, `partida <id> sala "x" puerto P semilla S`,
## `sala "x" resultado {…}`. `--match-args=` passes extra user args to the dedicated processes (tests).

@onready var launcher: MpMatchLauncher = %Launcher
@onready var rules: SacrificeRoomRules = %Rules

var _announced: Dictionary = {}
var _result_seen: Dictionary = {}


## Before the launcher's own _ready: `--lobby-config=res://….tres` replaces the config it was saved with.
func _enter_tree() -> void:
	var path := MpBoot.user_value("lobby-config", "")
	if path.is_empty():
		return
	var chosen := load(path) as MpLobbyConfig
	if chosen == null:
		push_error("--lobby-config=%s: not an MpLobbyConfig" % path)
		return
	(get_node("%Launcher") as MpMatchLauncher).config = chosen


func _ready() -> void:
	if launcher.base_args.is_empty():
		# An exported binary carries its project (no `--path`); from the editor's binary it needs the folder.
		launcher.base_args = PackedStringArray(["--headless"])
		if not OS.has_feature("template"):
			launcher.base_args.append_array(
				PackedStringArray(["--path", ProjectSettings.globalize_path("res://")])
			)
	# `--match-engine-args=--fixed-fps,600` adds ENGINE args (before the `--`) to every dedicated: the tests run the match without waiting
	# for real time. Comma-separated; a flag with a value is two items.
	var engine_extra := MpBoot.user_value("match-engine-args", "")
	if not engine_extra.is_empty():
		launcher.base_args.append_array(engine_extra.split(",", false))
	# `--match-args=--flag=1,--other` adds user args to every dedicated this server launches (tests only).
	var extra := MpBoot.user_value("match-args", "")
	if not extra.is_empty():
		launcher.agent_args.append_array(extra.split(",", false))
	rules.bind(MpLobby.server)
	var err := MpLobby.start_server(launcher.config, launcher)
	if err != OK:
		push_error("room server: port %d: %s" % [launcher.config.lobby_port, error_string(err)])
		get_tree().quit(1)
		return
	var rooms := MpLobby.server.rooms
	rooms.match_assigned.connect(_on_match_assigned)
	rooms.room_changed.connect(_on_room_changed)
	rooms.room_error.connect(
		func(room_id: String, code: String) -> void:
			print('sala "%s" error %s' % [MpLobby.server.name_of_room(room_id), code])
	)
	launcher.match_failed.connect(
		func(match_id: String, reason: String) -> void:
			print("partida %s fallo %s" % [match_id, reason])
	)
	print("salas listo puerto %d" % launcher.config.lobby_port)


func _on_match_assigned(room_id: String, _session_id: String, port: int, _token: String) -> void:
	var match_id := MpLobby.server.rooms.match_id_of(room_id)
	if match_id.is_empty() or _announced.has(match_id):
		return
	_announced[match_id] = true
	var ticket := MpMatchFiles.read_json(
		MpMatchFiles.path_of(launcher.config.matches_root, match_id, MpMatchFiles.TICKET)
	)
	print(
		(
			'partida %s sala "%s" puerto %d semilla %d'
			% [match_id, MpLobby.server.name_of_room(room_id), port, int(ticket.get("seed", 0))]
		)
	)


func _on_room_changed(room_id: String) -> void:
	var result := MpLobby.server.rooms.last_result_of(room_id)
	if result.is_empty() or _result_seen.get(room_id, 0) == result.hash():
		return
	_result_seen[room_id] = result.hash()
	print('sala "%s" resultado %s' % [MpLobby.server.name_of_room(room_id), JSON.stringify(result)])
