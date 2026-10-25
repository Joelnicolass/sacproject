extends "res://addons/mp_kit/tests/mp_test.gd"

## Mp (the short way) and MpGame (one .tres): offline answers, and a flow filled from the game.


func test_offline_answers() -> void:
	check(not Mp.is_online(), "offline: not online")
	check(Mp.is_server() == MpKit.is_authority(), "is_server is where the rules run (MpKit.is_authority)")
	check(Mp.me() == MpKit.local_slot(), "me is the local slot")
	check(Mp.current_match() == null and Mp.player(1) == null, "no match and no player outside a world")


func test_game_fills_the_flow() -> void:
	var game := MpGame.new()
	game.boot_scene = "res://g/boot.tscn"
	game.world_scene = "res://g/world.tscn"
	game.lobby_scene = "res://g/lobby.tscn"
	game.rooms_scene = "res://g/rooms.tscn"
	game.max_players = 6
	var flow := MpFlow.new()
	flow.game = game
	flow.lobby_path = "res://mine/lobby.tscn"
	flow._use_game()
	check(flow.net_config == game, "the game is the network .tres (an MpGame is an MpNetConfig)")
	check(flow.boot_path == game.boot_scene and flow.world_path == game.world_scene and flow.room_server_path == game.rooms_scene, "empty scene paths come from the game")
	check(flow.lobby_path == "res://mine/lobby.tscn", "a path set on the flow wins")
	check(flow.net_config.effective_max_players() == 6, "the game's network settings are used")
	flow.free()
