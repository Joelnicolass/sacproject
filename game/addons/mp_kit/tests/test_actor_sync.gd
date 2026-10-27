extends "res://addons/mp_kit/tests/mp_test.gd"

## MpActorSync: what an MpActor's synchronizer sends in each mode (no tree, no network).


func _actor(with_input: bool) -> Array:
	var parent := Node2D.new()
	var actor := MpActor.new()
	actor.name = "MpActor"
	parent.add_child(actor)
	if with_input:
		var mp_input := MpInput.new()
		mp_input.name = "MpInput"
		parent.add_child(mp_input)
	return [parent, actor]


func test_plain_mode_syncs_the_node() -> void:
	var made := _actor(false)
	var actor: MpActor = made[1]
	actor.smoothing = MpActor.Smoothing.NONE
	check(actor.sync_entries() == PackedStringArray(["position", "rotation"]), "without smoothing the node's own pose is sent")
	made[0].free()


func test_smoothing_sends_the_net_pose() -> void:
	var made := _actor(false)
	var actor: MpActor = made[1]
	actor.sync_extra = PackedStringArray(["health"])
	var want := PackedStringArray(["MpActor:net_position", "MpActor:net_rotation", "health", "MpActor:net_stamp", "MpActor:net_teleports"])
	check(actor.sync_entries() == want, "buffered smoothing sends MpActor's pose and stamp, never the node's")
	made[0].free()


func test_prediction_sends_the_ack() -> void:
	var made := _actor(true)
	var actor: MpActor = made[1]
	actor.sync_rotation = false
	actor.predict = true
	var want := PackedStringArray(["MpActor:net_position", "MpActor:net_stamp", "MpActor:net_teleports", "MpInput:acked_seq"])
	check(actor.sync_entries() == want, "prediction adds MpInput's ack to the same packet")
	made[0].free()


func test_snap_on_the_server_rides_with_the_next_pose() -> void:
	var made := _actor(false)
	var parent: Node2D = made[0]
	var actor: MpActor = made[1]
	tree.root.add_child(parent)
	actor._publish_pose()
	var before := actor.net_teleports
	parent.position = Vector2(500, 0)
	actor.snap()
	check(actor.net_teleports == before, "not in the state already published (it has the old pose)")
	actor._publish_pose()
	check(actor.net_teleports == before + 1 and actor.net_position.x == 500.0, "in the next one, with the moved pose")
	actor._publish_pose()
	check(actor.net_teleports == before + 1, "and it stays: a client compares two states")
	parent.free()
