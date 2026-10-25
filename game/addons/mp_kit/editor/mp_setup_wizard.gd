@tool
class_name MpSetupWizard
extends RefCounted

## Writes a working multiplayer game from a few choices (Project > Tools > MpKit: Setup game...): a boot menu with
## MpFlow, a world (spawn points, MpSlotSpawner, MpState, MpMatch), a predicted player (MpActor + MpInput) and the
## network .tres; optionally the online rooms (room server, lobby screen). It never overwrites a file: `plan()` says
## what exists, and `write()` refuses then. No editor needed (the tests run it headless). Not: your game rules.

const BOOT := "boot.tscn"
const WORLD := "world.tscn"
const PLAYER := "player.tscn"
const PLAYER_SCRIPT := "player.gd"
const NET := "net.tres"
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
	var names := [NET, PLAYER_SCRIPT, PLAYER, WORLD, BOOT]
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
	var net := MpNetConfig.new()
	net.transport = transport
	net.relay_url = relay_url
	## The project's name plus a random tail: two games made with this wizard on one relay never share rooms.
	net.relay_room = "%s-%s" % [_relay_name(), Crypto.new().generate_random_bytes(3).hex_encode()]
	net.max_players = max_players
	err = ResourceSaver.save(net, _p(NET))
	if err == OK:
		err = _save_text(_p(PLAYER_SCRIPT), MpSetupTemplates.player_script(dimension_3d))
	if err == OK:
		err = _save_scene(MpSetupTemplates.player(dimension_3d, load(_p(PLAYER_SCRIPT))), _p(PLAYER))
	if err == OK:
		err = _save_scene(MpSetupTemplates.world(dimension_3d, max_players, load(_p(PLAYER))), _p(WORLD))
	if err == OK and online_rooms:
		## The room server takes transport, relay and TLS from net.tres (MpRoomServer.net_config): one place.
		var config := MpLobbyConfig.new()
		config.seats_per_room = mini(max_players, 2)
		err = ResourceSaver.save(config, _p(ROOMS_CONFIG))
		if err == OK:
			err = _save_scene(MpSetupTemplates.room_server(load(_p(ROOMS_CONFIG)), load(_p(NET))), _p(ROOMS))
		if err == OK:
			err = _save_scene(MpSetupTemplates.lobby(_p(BOOT)), _p(LOBBY))
	if err == OK:
		var paths := {"boot": _p(BOOT), "world": _p(WORLD), "lobby": _p(LOBBY) if online_rooms else "",
			"rooms": _p(ROOMS) if online_rooms else ""}
		err = _save_scene(MpSetupTemplates.boot(load(_p(NET)), paths, private_server), _p(BOOT))
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
