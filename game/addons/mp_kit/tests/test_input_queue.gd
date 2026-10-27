extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInputQueue: the server applies the owner's frames in order, each once, evenly, whatever the network did; it never
## stops a player: a frame that is not there in time is guessed (the last one again) and dropped when it comes.


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
	check(_seqs(q.take_for_tick()) == [4] and q.guessed == 1, "starved, it repeats the last frame for the next seq: the player does not stop")
	q.add(_frame(4))
	check(q.waiting() == 0, "the late frame 4 is dropped: its tick went by")
	q.add(_frame(5))
	check(_seqs(q.take_for_tick()) == [5], "the owner's next frame counts again")


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
	## Ticks before the first frames come fill the bank (BURST): only banked ticks can take a second frame.
	for i in MpInputQueue.BURST + 2:
		q.take_for_tick()
	for seq in range(1, 10):
		q.add(_frame(seq))
	check(q.take_for_tick().size() == 1, "a few frames ahead it still takes one per tick (the owner sends less instead)")
	for seq in range(10, 10 + MpInputQueue.CATCH_UP + 4):
		q.add(_frame(seq))
	check(q.take_for_tick().size() == 2, "far ahead (more than CATCH_UP beyond the depth) it takes two per tick")
	var real: Array = []
	for i in 40:
		real.append_array(_seqs(q.take_for_tick()).filter(func(s: int) -> bool: return s < 10 + MpInputQueue.CATCH_UP + 4))
	check(real == range(4, 10 + MpInputQueue.CATCH_UP + 4), "every frame is simulated once, in order: %s" % [real])
	for seq in range(100, 300):
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


func test_a_missing_frame_is_guessed_and_dropped_when_late() -> void:
	var q := MpInputQueue.new()
	q.depth = 1
	for seq in [1, 2, 4, 5]:
		q.add(_frame(seq))
	check(_seqs(q.take_for_tick()) == [1] and _seqs(q.take_for_tick()) == [2], "the frames before the hole go out")
	check(_seqs(q.take_for_tick()) == [3] and q.guessed == 1, "frame 3 is not there: the server guesses it (frame 2 again)")
	q.add(_frame(3))
	var after: Array = []
	for i in 2:
		after.append_array(_seqs(q.take_for_tick()))
	check(after == [4, 5], "the late 3 is dropped; 4 and 5 run in order: %s" % [after])


func test_guesses_let_go_of_the_keys_after_a_while() -> void:
	var q := MpInputQueue.new()
	q.depth = 1
	var held := MpInputFrame.sized(1)
	held.seq = 1
	held.record(0, 1.0, true, false)
	q.add(held)
	q.take_for_tick()
	var strengths: Array = []
	for i in MpInputQueue.MAX_GUESSES + 3:
		strengths.append(q.take_for_tick()[0].strengths[0])
	check(strengths.slice(0, MpInputQueue.MAX_GUESSES).all(func(s: float) -> bool: return s == 1.0), "a short gap: the held key stays held")
	check(strengths.slice(MpInputQueue.MAX_GUESSES).all(func(s: float) -> bool: return s == 0.0), "after MAX_GUESSES the keys are let go (a client that froze)")


func test_a_server_ahead_of_the_clock_waits_instead_of_guessing() -> void:
	var q := MpInputQueue.new()
	q.depth = 1
	q.add(_frame(1))
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	check(_seqs(q.take_for_tick(10.0)) == [1], "the frame goes out")
	var early := 0
	for i in 50:
		early += q.take_for_tick(10.0 + tick * 0.01 * (i + 1)).size()
	check(early == 0 and q.guessed == 0, "fifty ticks within half a real tick (a server racing the clock): no frame and no guess")
	q.add(_frame(2))
	check(_seqs(q.take_for_tick(10.0 + tick * 1.1)) == [2], "a real tick on, the owner's frame")
	check(_seqs(q.take_for_tick(10.0 + tick * 2.2)) == [3] and q.guessed == 1, "another real tick with nothing: late, it guesses")
	q.add(_frame(9))
	for i in 6:
		q.add(_frame(4 + i))
	var caught := 0
	for i in 8:
		caught += q.take_for_tick(10.0 + tick * 8.0).size()
	check(caught <= 1 + MpInputQueue.BURST, "a burst of ticks after a hitch takes at most the banked real ticks (%d)" % caught)
