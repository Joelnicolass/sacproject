extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInputFrame: what travels from the owner to the server, and how presses survive lost packets.


func test_presses_survive_lost_packets() -> void:
	var seen := MpInputFrame.sized(2)
	var lost := seen.next()
	lost.record(0, 1.0, true, false)
	var arrived := lost.next()
	arrived.record(0, 0.0, false, true)
	check(arrived.pressed_since(seen, 0), "the press of a lost frame still shows in the next one")
	check(arrived.released_since(seen, 0), "and so does the release")
	check(not arrived.pressed_since(arrived, 0), "a frame against itself is no new press")
	check(not arrived.pressed_since(seen, 1), "the other action was not pressed")


func test_seq_grows_and_input_is_kept() -> void:
	var a := MpInputFrame.sized(1)
	a.record(0, 0.5, false, false)
	var b := a.next()
	check(b.seq == a.seq + 1, "next() advances seq by one")
	check(b.same_as(a), "next() keeps the input (nothing new to send)")
	b.values[&"aim"] = Vector2(1, 2)
	check(not b.same_as(a), "a new custom value is something to send")


func test_strengths_are_kept_as_they_travel() -> void:
	var f := MpInputFrame.sized(1)
	f.record(0, 0.3333, false, false)
	check(f.strengths[0] == PackedFloat32Array([MpInputFrame.quantize_byte(0.3333) / 255.0])[0], "a strength is stored in the 1/255 steps it travels in")
	f.record(0, 2.0, false, false)
	check(f.strengths[0] == 1.0, "clamped to 1")
	f.record(0, NAN, false, false)
	check(f.strengths[0] == 0.0, "NaN is 0")
