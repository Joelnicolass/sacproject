extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInputQueue: the server applies the owner's frames in order, each once, evenly, whatever the network did.


func _frame(seq: int) -> MpInputFrame:
	var f := MpInputFrame.sized(1)
	f.seq = seq
	return f


func _seqs(frames: Array[MpInputFrame]) -> Array:
	return frames.map(func(f: MpInputFrame) -> int: return f.seq)


func test_buffers_then_one_per_tick() -> void:
	var q := MpInputQueue.new()
	q.depth = 3
	q.add(_frame(1))
	q.add(_frame(2))
	check(q.take_for_tick().is_empty(), "below depth the server waits (jitter buffer)")
	q.add(_frame(3))
	check(_seqs(q.take_for_tick()) == [1], "at depth it takes one frame")
	check(_seqs(q.take_for_tick()) == [2], "and one per tick after that")
	check(_seqs(q.take_for_tick()) == [3], "even with fewer than depth left")
	check(q.take_for_tick().is_empty(), "starved, it takes nothing")
	q.add(_frame(4))
	check(q.take_for_tick().is_empty(), "after starving it buffers again")


func test_order_and_copies() -> void:
	var q := MpInputQueue.new()
	q.depth = 1
	for seq in [2, 1, 3, 2, 3]:
		q.add(_frame(seq))
	check(q.waiting() == 3, "redundant copies are dropped")
	check(_seqs(q.take_for_tick()) == [1] and _seqs(q.take_for_tick()) == [2], "frames come out in seq order")
	q.take_for_tick()
	q.add(_frame(2))
	check(q.waiting() == 0 and q.last_seq() == 3, "a frame older than the last applied is dropped")


func test_catch_up_is_gentle_and_capped() -> void:
	var q := MpInputQueue.new()
	q.depth = 2
	for seq in range(1, 10):
		q.add(_frame(seq))
	check(q.take_for_tick().size() == 2, "far behind it takes two per tick")
	var total := 0
	for i in 20:
		total += q.take_for_tick().size()
	check(total == 7, "every frame is simulated once")
	for seq in range(10, 200):
		q.add(_frame(seq))
	check(q.waiting() <= MpInputQueue.MAX_WAITING + 200, "frames are kept until the next tick")
	var taken := 0
	for i in 10:
		taken += q.take_for_tick().size()
	check(taken <= 10 + MpInputQueue.BURST, "a flood never moves the player faster than one frame per tick plus the bank")


func test_adaptive_depth_follows_lateness() -> void:
	var q := MpInputQueue.new()
	q.adaptive = true
	q.depth = 1
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	for seq in range(1, 121):
		q.add(_frame(seq), seq * tick)
		q.take_for_tick()
	check(q.wanted_depth() == 1 and q.depth == 1, "frames that arrive on time: a one-tick buffer")
	var q2 := MpInputQueue.new()
	q2.adaptive = true
	q2.depth = 1
	for seq in range(1, 121):
		var late := (3.0 * tick) if seq % 10 == 0 else 0.0
		q2.add(_frame(seq), seq * tick + late)
		q2.take_for_tick()
	check(q2.wanted_depth() >= 4, "one frame in ten three ticks late: the buffer covers it (%d)" % q2.wanted_depth())
	check(q2.depth >= q2.wanted_depth(), "and the depth follows")
	check(q2.slack() == q2.waiting() - q2.depth, "slack is what waits beyond the depth")
