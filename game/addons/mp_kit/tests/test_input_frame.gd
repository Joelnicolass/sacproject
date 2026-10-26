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


func test_pack_round_trip() -> void:
	var a := MpInputFrame.sized(2).next()
	a.record(1, 0.25, true, false)
	a.values[&"aim"] = Vector2(3, 4)
	var b := MpInputFrame.unpack(a.pack(), 2)
	check(b != null and b.same_as(a) and b.seq == a.seq, "unpack(pack()) gives the same frame")


func test_unpack_refuses_bad_packets() -> void:
	var good := MpInputFrame.sized(2).pack()
	check(MpInputFrame.unpack(good, 3) == null, "a frame for another number of actions is refused")
	check(MpInputFrame.unpack([1, 2, 3], 2) == null, "a packet of the wrong shape is refused")
	var wrong_type := good.duplicate()
	wrong_type[1] = "x"
	check(MpInputFrame.unpack(wrong_type, 2) == null, "a packet with the wrong types is refused")
	var many := good.duplicate()
	var values := {}
	for i in MpInputFrame.MAX_VALUES + 1:
		values[i] = i
	many[4] = values
	check(MpInputFrame.unpack(many, 2) == null, "too many custom values are refused")
	var big := good.duplicate()
	big[4] = {&"blob": "x".repeat(MpInputFrame.MAX_BYTES)}
	check(MpInputFrame.unpack(big, 2) == null, "an oversized packet is refused")


func test_unpack_clamps_strengths() -> void:
	var data := MpInputFrame.sized(3).pack()
	data[1] = PackedFloat32Array([5.0, -2.0, NAN])
	var frame := MpInputFrame.unpack(data, 3)
	check(frame.strengths == PackedFloat32Array([1.0, 0.0, 0.0]), "strengths are clamped to 0..1 and NaN is 0")
