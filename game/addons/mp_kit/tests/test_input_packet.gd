extends "res://addons/mp_kit/tests/mp_test.gd"

## MpInputPacket: a run of input frames, delta-coded; what comes out is what went in, small, and nothing a hostile
## client sends gets through.


## Frames 10..(10+n-1) for 2 actions, holding action 0 and turning an aim from frame 3 on, view 1/60 apart.
func _run(n: int) -> Array[MpInputFrame]:
	var frames: Array[MpInputFrame] = []
	var f := MpInputFrame.sized(2)
	f.seq = 10
	f.view = 100.0
	f.record(0, 1.0, true, false)
	frames.append(f)
	for i in range(1, n):
		var g := frames[i - 1].next()
		g.view = frames[i - 1].view + 1.0 / 60.0
		if i == 3:
			g.record(1, 0.5, true, false)
			g.values[&"aim"] = Vector2(3, 4)
		if i == 5:
			g.record(0, 0.0, false, true)
		frames.append(g)
	return frames


func _same(a: Array[MpInputFrame], b: Array[MpInputFrame]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i].seq != b[i].seq or not a[i].same_as(b[i]) or absf(a[i].view - b[i].view) > 0.000002:
			return false
	return true


func test_round_trip() -> void:
	var frames := _run(8)
	var back := MpInputPacket.decode(MpInputPacket.encode(frames), 2)
	check(_same(frames, back), "decode(encode()) gives the same frames: seqs, strengths, presses, releases, values, view")
	check(back[3].pressed_since(back[2], 1) and back[5].released_since(back[4], 0), "presses and releases land on their frames")


func test_small_when_the_keys_stay() -> void:
	var held: Array[MpInputFrame] = []
	var f := MpInputFrame.sized(6)
	f.record(0, 1.0, true, false)
	f.values[&"aim"] = Vector2(300, 200)
	held.append(f)
	for i in 15:
		held.append(held[held.size() - 1].next())
	var one := MpInputPacket.encode(held.slice(0, 1)).size()
	var size := MpInputPacket.encode(held).size()
	check(size - one <= 15 * 5, "each frame that keeps the keys adds at most 5 bytes (16 frames: %d bytes, the first %d)" % [size, one])


func test_keeps_the_newest() -> void:
	var frames: Array[MpInputFrame] = [MpInputFrame.sized(1)]
	for i in MpInputPacket.MAX_FRAMES + 5:
		frames.append(frames[frames.size() - 1].next())
	var back := MpInputPacket.decode(MpInputPacket.encode(frames), 1)
	check(back.size() == MpInputPacket.MAX_FRAMES and back[back.size() - 1].seq == frames[frames.size() - 1].seq, "past MAX_FRAMES the newest go")


func test_refuses_what_does_not_fit() -> void:
	var good := MpInputPacket.encode(_run(4))
	check(MpInputPacket.decode(good, 3).is_empty(), "another number of actions is refused")
	check(MpInputPacket.decode(good.slice(0, good.size() - 1), 2).is_empty(), "a cut packet is refused")
	var longer := good.duplicate()
	longer.append(0)
	check(MpInputPacket.decode(longer, 2).is_empty(), "bytes after the last frame are refused")
	check(MpInputPacket.decode(PackedByteArray([1, 2, 0]), 2).is_empty(), "a packet too short to be one is refused")
	var many := {}
	for i in MpInputFrame.MAX_VALUES + 1:
		many[i] = i
	var f := MpInputFrame.sized(2)
	f.values = many
	check(MpInputPacket.decode(MpInputPacket.encode([f]), 2).is_empty(), "too many custom values are refused")
	var blob := MpInputFrame.sized(2)
	blob.values = {&"blob": "x".repeat(MpInputFrame.MAX_BYTES)}
	check(MpInputPacket.decode(MpInputPacket.encode([blob]), 2).is_empty(), "oversized values are refused")
	var not_dict := good.duplicate()
	## The first frame's values: replace the empty values (size 0) with a 4-byte int.
	var header := 15 + 2 * 9
	not_dict = not_dict.slice(0, header) + PackedByteArray([8, 0]) + var_to_bytes(7) + not_dict.slice(header + 2)
	check(MpInputPacket.decode(not_dict, 2).is_empty(), "values that are not a Dictionary are refused")
	var frames_over := good.duplicate()
	frames_over[2] = MpInputPacket.MAX_FRAMES + 1
	check(MpInputPacket.decode(frames_over, 2).is_empty(), "a frame count over MAX_FRAMES is refused")


func test_big_values_keep_the_packet_one_datagram() -> void:
	var frames: Array[MpInputFrame] = [MpInputFrame.sized(1)]
	for i in 30:
		var f := frames[frames.size() - 1].next()
		f.values = {&"blob": "x".repeat(200) + str(i)}
		frames.append(f)
	var bytes := MpInputPacket.encode(frames)
	var back := MpInputPacket.decode(bytes, 1)
	check(bytes.size() <= MpInputPacket.TARGET_BYTES, "under one datagram (%d bytes)" % bytes.size())
	check(not back.is_empty() and back[back.size() - 1].seq == frames[frames.size() - 1].seq, "with the newest frames (%d of them)" % back.size())


func test_values_travel_exactly() -> void:
	var f := MpInputFrame.sized(1)
	f.values = {&"yaw": PI / 3.0, &"aim": Vector2(0.1234567, -7.654321), &"big": 123456789.123456789}
	var g := f.next()
	g.values = {&"yaw": -2.9999999999, &"aim": Vector2(0.1234567, -7.654321), &"big": 123456789.123456789}
	var back := MpInputPacket.decode(MpInputPacket.encode([f, g]), 1)
	check(back.size() == 2 and back[0].values == f.values and back[1].values == g.values, "values arrive bit for bit (64-bit floats included): %s" % [back[1].values if back.size() == 2 else []])
