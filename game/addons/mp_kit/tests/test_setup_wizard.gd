extends "res://addons/mp_kit/tests/mp_test.gd"

## MpSetupWizard: a few choices become a working game folder; existing files are never overwritten.


func _wizard(folder: String, is_3d: bool) -> MpSetupWizard:
	_clean(folder)
	var wizard := MpSetupWizard.new()
	wizard.folder = folder
	wizard.dimension_3d = is_3d
	wizard.max_players = 3
	return wizard


func test_writes_a_2d_game_once() -> void:
	var wizard := _wizard("user://mpkit_wizard_2d", false)
	check(not wizard.plan_text().contains("[~]") and wizard.plan_text().contains("[+] user://mpkit_wizard_2d/boot.tscn"), "the plan lists new files")
	check(wizard.write() == OK, "the game is written")
	check(wizard.plan_text().contains("[~]") and not wizard.plan_text().contains("[+]"), "now every file exists")
	check(wizard.write() == ERR_ALREADY_EXISTS, "a second write refuses to overwrite")
	var world: Node = (load("user://mpkit_wizard_2d/world.tscn") as PackedScene).instantiate()
	check(world.get_node("SpawnPoints").get_child_count() == 3, "one spawn point per player")
	check(world.get_node("Players") is MpSlotSpawner and world.get_node("Players").get("pawn_scene") != null, "the slot spawner has the player")
	check(world.get_node("Score") is MpState and world.get_node_or_null("Score/MpSync") != null, "MpState with its synchronizer")
	check(world.get_node("Match") is MpMatch, "MpMatch in the world")
	world.free()
	var player: Node = (load("user://mpkit_wizard_2d/player.tscn") as PackedScene).instantiate()
	var actor := MpActor.of(player)
	var sync := player.get_node("MpActor/MpSync") as MultiplayerSynchronizer
	check(actor != null and actor.predict, "the player has a predicted MpActor")
	check(sync != null and sync.replication_config.has_property(^"MpActor:net_position") and sync.replication_config.has_property(^"MpInput:acked_seq"), "the player's synchronizer is built")
	check(player.has_method(&"mp_move"), "the player script has mp_move")
	player.free()
	var boot: Node = (load("user://mpkit_wizard_2d/boot.tscn") as PackedScene).instantiate()
	check(boot.get_node("Flow").get("net_config") is MpNetConfig, "the boot's flow has the network .tres")
	check(str(boot.get_node("Flow").get("lobby_path")).ends_with("lobby.tscn"), "the flow knows the lobby")
	boot.free()


func test_writes_a_3d_game_without_rooms() -> void:
	var wizard := _wizard("user://mpkit_wizard_3d", true)
	wizard.online_rooms = false
	check(not wizard.plan_text().contains("lobby.tscn"), "without rooms there is no lobby in the plan")
	check(wizard.write() == OK, "the 3D game is written")
	var player: Node = (load("user://mpkit_wizard_3d/player.tscn") as PackedScene).instantiate()
	check(player is CharacterBody3D and player.get_node("Visual") is MeshInstance3D, "a 3D player")
	player.free()


func _clean(folder: String) -> void:
	var dir := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)
