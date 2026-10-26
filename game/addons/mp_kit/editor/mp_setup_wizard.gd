@tool
class_name MpSetupWizard
extends RefCounted

## Writes a working multiplayer game from a few choices (Project > Tools > MpKit: Setup game...): game.tres (an
## MpGame: the network and the scenes), a boot menu with an MpFlow that only has that .tres, a world with one MpWorld
## (it builds spawn points, spawner, MpState, MpMatch and a Leave button), a predicted player (MpActor + MpInput);
## optionally the online rooms (room server, lobby screen), which read everything from game.tres too. It never overwrites a file: `plan()` says
## what exists, and `write()` refuses then. No editor needed (the tests run it headless). Not: your game rules.

const BOOT := "boot.tscn"
const WORLD := "world.tscn"
const PLAYER := "player.tscn"
const PLAYER_SCRIPT := "player.gd"
const GAME := "game.tres"
## Deprecated name: the network lives in GAME (an MpGame is an MpNetConfig).
const NET := GAME
const LOBBY := "lobby.tscn"
const ROOMS := "rooms.tscn"
const ROOMS_CONFIG := "rooms_config.tres"

var folder: String = "res://game"
var dimension_3d: bool = false
var max_players: int = 4
var transport: String = "enet"
## relay transport: the relay's address (the secret never goes in the game; see relay/README.md).
var relay_url: String = ""
var online_rooms: bool = true
var private_server: bool = true


## Every file `write()` would create, with whether it already exists: [{path, exists}].
func plan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := [GAME, PLAYER_SCRIPT, PLAYER, WORLD, BOOT]
	if online_rooms:
		names.append_array([ROOMS_CONFIG, ROOMS, LOBBY])
	for file in names:
		var path := folder.path_join(file)
		out.append({"path": path, "exists": FileAccess.file_exists(path) or ResourceLoader.exists(path)})
	return out


## The plan as the file tree people review: "[+] res://game/boot.tscn" (new) or "[~] …" (exists: nothing is written).
func plan_text() -> String:
	var lines := PackedStringArray()
	for row in plan():
		lines.append("%s %s" % ["[~]" if row["exists"] else "[+]", row["path"]])
	return "\n".join(lines)


func write() -> Error:
	for row in plan():
		if row["exists"]:
			push_error("MpSetupWizard: %s exists; nothing was written" % row["path"])
			return ERR_ALREADY_EXISTS
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if err != OK:
		return err
	var game := MpGame.new()
	game.transport = transport
	game.relay_url = relay_url
	## The project's name plus a random tail: two games made with this wizard on one relay never share rooms.
	game.relay_room = "%s-%s" % [_relay_name(), Crypto.new().generate_random_bytes(3).hex_encode()]
	game.max_players = max_players
	game.boot_scene = _p(BOOT)
	game.world_scene = _p(WORLD)
	game.lobby_scene = _p(LOBBY) if online_rooms else ""
	game.rooms_scene = _p(ROOMS) if online_rooms else ""
	err = ResourceSaver.save(game, _p(GAME))
	if err == OK:
		err = _save_text(_p(PLAYER_SCRIPT), MpSetupTemplates.player_script(dimension_3d))
	if err == OK:
		err = _save_scene(MpSetupTemplates.player(dimension_3d, load(_p(PLAYER_SCRIPT))), _p(PLAYER))
	if err == OK:
		err = _save_scene(MpSetupTemplates.world_with_mp_world(dimension_3d, max_players, load(_p(PLAYER))), _p(WORLD))
	if err == OK and online_rooms:
		## The room server takes transport, relay and TLS from game.tres through the flow: one place.
		var config := MpLobbyConfig.new()
		config.seats_per_room = mini(max_players, 2)
		err = ResourceSaver.save(config, _p(ROOMS_CONFIG))
		if err == OK:
			err = _save_scene(MpSetupTemplates.room_server(load(_p(ROOMS_CONFIG)), null), _p(ROOMS))
		if err == OK:
			err = _save_scene(MpSetupTemplates.lobby(""), _p(LOBBY))
	if err == OK:
		err = _save_scene(MpSetupTemplates.boot_with_game(load(_p(GAME)), private_server), _p(BOOT))
	return err


func _p(file: String) -> String:
	return folder.path_join(file)


func _save_text(path: String, text: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK


func _save_scene(root: Node, path: String) -> Error:
	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.free()
	if err != OK:
		return err
	return ResourceSaver.save(scene, path)


func _relay_name() -> String:
	var project := str(ProjectSettings.get_setting("application/config/name", "")).to_snake_case().replace("_", "-")
	if project.is_empty():
		project = folder.get_file().to_snake_case().replace("_", "-")
	return project if not project.is_empty() else "mpkit"
