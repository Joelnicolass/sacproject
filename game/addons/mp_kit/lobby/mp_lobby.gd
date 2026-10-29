extends Node

## Autoload `MpLobby` (after `MpKit`). A thin container with the children `Server` and `Client` under
## the same path on both sides (the RPCs need it). It gives them their own `SceneMultiplayer`, so the
## lobby link never touches `MpKit`'s peer. Nothing happens until `start_server()` or `connect_to()`.
## Tests and tools may instance this script more than once under other names (one lobby stack each).

var server: MpLobbyServer
var client: MpLobbyClient
var api: SceneMultiplayer


func _enter_tree() -> void:
	## Infrastructure: the lobby link (timeouts, resume) keeps going while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())


func _ready() -> void:
	server = MpLobbyServer.new()
	server.name = "Server"
	client = MpLobbyClient.new()
	client.name = "Client"
	server.client_node = client
	client.server_node = server
	add_child(server)
	add_child(client)


func start_server(config: MpLobbyConfig, launcher: MpMatchLauncher = null) -> Error:
	return server.start(config, launcher)


func connect_to(host: String, port: int, display_name: String) -> Error:
	return client.connect_to(host, port, display_name)
