extends "res://addons/mp_kit/tests/mp_test.gd"

## The world helpers, solo: MpState.watch (current value, then each change), MpLocalSeat (the seat on this screen,
## preview_slot) and MpSpawner.spawn_here (spawns where the rules run).


func test_state_watch_gives_the_current_value_then_changes() -> void:
	var state := MpState.new()
	tree.root.add_child(state)
	state.set_value(&"round", 2)
	var seen: Array = []
	var handle := state.watch(&"round", func(value: Variant) -> void: seen.append(value), 0)
	check(seen == [2], "watch calls back at once with the current value: %s" % [seen])
	state.set_value(&"score", 5)
	check(seen == [2], "another key does not call back")
	state.set_value(&"round", 3)
	check(seen == [2, 3], "a change of the key calls back with the new value: %s" % [seen])
	state.unwatch(handle)
	state.set_value(&"round", 4)
	check(seen == [2, 3], "after unwatch nothing more arrives")
	var empty: Array = []
	state.watch(&"missing", func(value: Variant) -> void: empty.append(value), -1)
	check(empty == [-1], "a key with no value yet gives the default")
	state.free()


func test_local_seat_solo_and_preview() -> void:
	var seat := MpLocalSeat.new()
	tree.root.add_child(seat)
	check(MpLocalSeat.of(seat) == seat, "of() finds it by group")
	check(seat.slot == MpKit.local_slot() and seat.is_mine(MpKit.local_slot()), "solo: the local slot is on this screen")
	check(not seat.is_mine(0), "seat 0 is never mine")
	check(not seat.is_online(), "solo: not online")
	var changes: Array[int] = []
	seat.changed.connect(func(slot: int) -> void: changes.append(slot))
	seat.preview_slot = 2
	seat._process(0.0)
	check(seat.slot == 2 and seat.is_mine(2) and changes == [2], "preview_slot shows the match as seat 2 and says so")
	seat.preview_slot = 0
	seat._process(0.0)
	check(seat.slot == MpKit.local_slot() and changes.size() == 2, "back to the own seat")
	seat.free()


func test_spawn_here_spawns_solo() -> void:
	var world := Node2D.new()
	world.name = "SpawnHereWorld"
	var actors := Node2D.new()
	actors.name = "Actors"
	world.add_child(actors)
	var spawner := MpSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = ^"../Actors"
	spawner.spawn_function = func(data: Variant) -> Node:
		var made := Node2D.new()
		made.name = "Made_%s" % str(data)
		return made
	world.add_child(spawner)
	tree.root.add_child(world)
	var node := spawner.spawn_here(7)
	check(node != null and node.get_parent() == actors and node.name == &"Made_7", "solo: spawn_here makes the node under spawn_path")
	var none := MpSpawner.new()
	none.spawn_path = ^"../Actors"
	world.add_child(none)
	check(none.spawn_here(1) == null, "without a spawn_function it says so and returns null")
	world.free()
