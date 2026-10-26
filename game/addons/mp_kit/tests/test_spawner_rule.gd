extends "res://addons/mp_kit/tests/mp_test.gd"

## MpSpawner: which nodes in spawn_path the engine replicates (only public facts: the spawnable list, spawn(data)).

const SHOT := "res://addons/mp_kit/examples/arena_2d/shot.tscn"


func test_listed_scene_and_spawn_function() -> void:
	var spawner := MpSpawner.new()
	spawner.add_spawnable_scene(SHOT)
	var listed: Node = (load(SHOT) as PackedScene).instantiate()
	check(spawner._is_replicated(listed), "a node of a listed scene is replicated")
	var by_hand := Node2D.new()
	check(not spawner._is_replicated(by_hand), "a node added by hand is not")
	spawner.spawn_function = func(_data: Variant) -> Node: return Node2D.new()
	spawner._wrap_spawn_function()
	var made: Node = spawner.spawn_function.call({})
	check(made.has_meta(MpSpawner.SPAWNED_META) and spawner._is_replicated(made), "a node spawn(data) made is replicated")
	spawner._wrap_spawn_function()
	check(spawner.spawn_function.get_method() == &"_marked_spawn", "wrapping twice keeps one wrapper")
	for node in [listed, by_hand, made, spawner]:
		node.free()
