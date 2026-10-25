extends "res://addons/mp_kit/tests/mp_test.gd"

## MpWorld: one node builds every piece of a networked world, once, owned by the scene so it is saved.


func test_builds_every_piece_once() -> void:
	var root := Node2D.new()
	var world := MpWorld.new()
	world.seats = 3
	root.add_child(world)
	world.owner = root
	MpWorld.build(world, root, false)
	for piece in MpWorld.PIECES:
		check(world.get_node_or_null(piece) != null and world.get_node(piece).owner == root, "%s is built and saved with the scene" % piece)
	check(world.get_node("SpawnPoints").get_child_count() == 3, "one spawn point per seat")
	check(world.get_node("SpawnPoints/P1") is Marker2D, "2D markers in a 2D world")
	check(world.get_node("Players") is MpSlotSpawner and world.get_node("Players").spawn_path == ^"../Actors", "the spawner puts players in Actors")
	check(world.get_node_or_null("State/MpSync") != null, "the state has its synchronizer")
	check(world.get_node_or_null("Hud/Leave") is MpLeaveButton, "a Leave button")
	var count := world.get_child_count()
	MpWorld.build(world, root, false)
	check(world.get_child_count() == count, "building again adds nothing")
	root.free()


func test_player_scene_reaches_the_spawner() -> void:
	var root := Node3D.new()
	var world := MpWorld.new()
	world.leave_button = false
	root.add_child(world)
	MpWorld.build(world, root, true)
	check(world.get_node("SpawnPoints/P1") is Marker3D, "3D markers in a 3D world")
	check(world.get_node_or_null("Hud") == null, "no Hud when Leave Button is off")
	var scene := PackedScene.new()
	scene.pack(Node3D.new())
	world.player_scene = scene
	check(world.get_node("Players").get("pawn_scene") == scene, "Player Scene is the spawner's pawn scene")
	root.free()


func test_packs_and_loads_back() -> void:
	var root := Node2D.new()
	root.name = "World"
	var world := MpWorld.new()
	world.name = "MpWorld"
	root.add_child(world)
	world.owner = root
	MpWorld.build(world, root, false)
	var packed := PackedScene.new()
	check(packed.pack(root) == OK, "the world packs")
	root.free()
	var again := packed.instantiate()
	check(again.get_node_or_null("MpWorld/Players") is MpSlotSpawner and again.get_node_or_null("MpWorld/Match") is MpMatch, "the pieces come back from the saved scene")
	again.free()
