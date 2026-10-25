class_name MpLocalServer
extends Node

## A private match on the player's own PC with the same code as the VPS: one dedicated process (your project with
## `--dedicated` and a ticket), no room server. The host joins it like any client; each other seat gets a short
## code. Friends join with "address:port#CODE" in the menu's address field; a third player without a code is turned
## away. Lives under the root (survives scene changes) and frees itself when the match ends or `stop()` is called.
##   var server := MpLocalServer.start_on(get_tree(), 2)
##   server.server_ready.connect(func(address, port, codes): show(codes))
## Not: a LAN listen server (MpFlow.host_lan is simpler there), the online lobby (MpRoomServer).

## The match process listens. `address`: this PC on the LAN ("" if none, or through the relay). `codes`: slot -> code for each other seat.
signal server_ready(address: String, port: int, codes: Dictionary)
signal server_failed(reason: String)
signal server_ended(result: Dictionary)

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 6

## Ports, match times and the matches folder (the defaults work for one match).
@export var config: MpLobbyConfig

var port: int = 0
var codes: Dictionary = {}
var _launcher: MpMatchLauncher
var _match_id: String = ""
var _host_token: String = ""
var _join_host: bool = true


## Creates the node under the root and starts a match with `seats` seats (slot 1 is this player).
static func start_on(tree: SceneTree, seats: int = 2, options: Dictionary = {}, join_host: bool = true) -> MpLocalServer:
	var server := MpLocalServer.new()
	server.name = "MpLocalServer"
	tree.root.add_child(server)
	server.start(seats, options, join_host)
	return server


func start(seats: int = 2, options: Dictionary = {}, join_host: bool = true) -> Error:
	_join_host = join_host
	if config == null:
		config = MpLobbyConfig.new()
		## The match talks like this process does: the game's MpNetConfig (transport, relay, TLS) when there is a
		## flow with one, what MpKit runs otherwise.
		var flow := MpFlow.find_in_tree(self)
		if flow and flow.net_config:
			flow.net_config.fill_lobby_config(config)
		config.transport = MpKit.transport
		if config.relay_url.is_empty():
			config.relay_url = MpTransport.relay_url
		if config.relay_room.is_empty():
			config.relay_room = MpTransport.relay_room
	_launcher = MpMatchLauncher.new()
	_launcher.name = "Launcher"
	_launcher.config = config
	_launcher.base_args = PackedStringArray(["--headless"])
	if not OS.has_feature("template"):
		_launcher.base_args.append_array(PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]))
	var extra := MpBoot.user_value("match-args", "")
	if not extra.is_empty():
		_launcher.agent_args.append_array(extra.split(",", false))
	add_child(_launcher)
	_launcher.match_listening.connect(_on_listening)
	_launcher.match_failed.connect(func(_id: String, reason: String) -> void: _fail(reason))
	_launcher.match_ended.connect(_on_ended)
	var rows: Array = []
	_host_token = MpMatchFiles.new_token()
	rows.append({"slot": 1, "token": _host_token, "meta": {}})
	for slot in range(2, seats + 1):
		var code := MpLocalServer.new_code()
		codes[slot] = code
		rows.append({"slot": slot, "token": code, "meta": {}})
	_match_id = "local_%d" % (Time.get_unix_time_from_system() as int)
	var err := _launcher.launch(_match_id, {"options": options, "seats": rows})
	if err != OK:
		_fail("launch_%s" % error_string(err))
	return err


## Kills the match process and frees this node.
func stop() -> void:
	if _launcher and not _match_id.is_empty():
		_launcher.abort(_match_id, "stopped")
	queue_free()


static func new_code() -> String:
	var out := ""
	for i in CODE_LENGTH:
		out += CODE_CHARS[randi() % CODE_CHARS.length()]
	return out


func _on_listening(_id: String, p_port: int) -> void:
	port = p_port
	## Through the relay friends need no address of this PC, only the port (it picks the room) and a code.
	var address := "" if MpTransport.normalize(config.transport) == MpTransport.RELAY else MpLan.get_local_ipv4()
	server_ready.emit(address, port, codes.duplicate())
	if _join_host:
		var flow := MpFlow.find_in_tree(self)
		if flow:
			flow.join_endpoint("127.0.0.1", port, _host_token)


func _on_ended(_id: String, result: Dictionary) -> void:
	server_ended.emit(result)
	queue_free()


func _fail(reason: String) -> void:
	push_warning("MpLocalServer: %s" % reason)
	server_failed.emit(reason)
	queue_free()
