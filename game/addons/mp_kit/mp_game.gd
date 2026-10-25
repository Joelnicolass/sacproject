class_name MpGame
extends MpNetConfig

## Your whole multiplayer game in one .tres: the network (everything an MpNetConfig has: transport, port, players,
## relay, TLS) and its scenes. Give it to the MpFlow of your boot scene (Flow › Game) and the rest reads it from
## there: the menu offers "Online rooms" when there is a lobby scene, the lobby screen goes back to the boot scene,
## the room server talks like the game. Nothing is typed twice.
## Not: the rules of the online rooms (MpLobbyConfig and MpRoomRules live in your rooms scene).

@export_group("Scenes")
## The first scene, with the MpFlow and the menu. Leave and a lost server come back here.
@export_file("*.tscn") var boot_scene: String = ""
## The match: the scene with the MpWorld (or your own spawner, MpState and MpMatch).
@export_file("*.tscn") var world_scene: String = ""
## Optional: the online lobby (an MpLobbyScreen). Empty = the menu has no "Online rooms".
@export_file("*.tscn") var lobby_scene: String = ""
## Optional: the room server (an MpRoomServer). `--room-server` opens it.
@export_file("*.tscn") var rooms_scene: String = ""
