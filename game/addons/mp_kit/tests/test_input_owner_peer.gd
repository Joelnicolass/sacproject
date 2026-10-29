extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInput on the server, when the seat's connection changes: a rejoin is a new connection whose frames count from
## 1 again, and a seat with no connection holds no keys.


func _input_with_key_held() -> MpInput:
	var parent := Node2D.new()
	var actor := MpActor.new()
	actor.name = "MpActor"
	parent.add_child(actor)
	var input := MpInput.new()
	input.name = "MpInput"
	input.actor = actor
	parent.add_child(input)
	tree.root.add_child(parent)
	var held := MpInputFrame.sized(input.actions.size())
	held.seq = 900
	held.record(0, 1.0, true, false)
	input.use_frame(held, held, false)
	input.acked_seq = 900
	input._queue.add(held)
	input._owner_peer = 7
	return input


func test_a_new_connection_starts_the_input_over() -> void:
	var input := _input_with_key_held()
	input._follow_owner_peer(8)
	check(input.acked_seq == 0, "the ack starts again (the new owner replays from its own first frame)")
	check(input.get_action_strength(&"ui_left") == 0.0, "no key held until the new connection sends one")
	var first := MpInputFrame.sized(input.actions.size())
	first.seq = 1
	input._queue.add(first)
	check(input._queue.waiting() == 1, "its frame 1 is taken (it would be dropped as old by the previous stream)")
	input.get_parent().free()


func test_the_same_connection_keeps_its_stream() -> void:
	var input := _input_with_key_held()
	input._follow_owner_peer(7)
	check(input.acked_seq == 900 and input.get_action_strength(&"ui_left") == 1.0, "nothing changes for the same connection")
	input._follow_owner_peer(0)
	check(input.get_action_strength(&"ui_left") == 0.0 and input.acked_seq == 0, "no connection: the keys are let go")
	input.get_parent().free()
