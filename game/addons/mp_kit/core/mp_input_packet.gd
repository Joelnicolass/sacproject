class_name MpInputPacket
extends RefCounted

## A run of consecutive input frames as one compact packet, delta-coded as Quake's and Overwatch's commands are: the
## first frame whole, each next one only with what changed (a frame that keeps the same keys is 5 bytes). So the
## owner can send every frame the server has not confirmed yet, and a burst of lost packets loses none of them.
## Decoding checks everything (a broken or hostile client): the action count, sizes, value types. Pure data.
## Not: what is in a frame (MpInputFrame), who sends what (MpInput).

const VERSION := 1
## Most frames one packet carries.
const MAX_FRAMES := 32
## The largest packet accepted.
const MAX_BYTES := 4096
## What encode() keeps a packet under, dropping its oldest frames: one datagram (a fragmented one is lost whole when
## any piece is).
const TARGET_BYTES := 1200

const _CHANGED_STRENGTHS := 1
const _CHANGED_COUNTERS := 2
const _CHANGED_VALUES := 4


## `frames`: oldest first; the newest consecutive run of them is sent (at most MAX_FRAMES, and as many as fit in
## TARGET_BYTES: big custom values that change every frame leave fewer).
static func encode(frames: Array[MpInputFrame]) -> PackedByteArray:
	var from := frames.size() - 1
	while from > 0 and frames.size() - from < MAX_FRAMES and frames[from - 1].seq == frames[from].seq - 1:
		from -= 1
	var run := frames.slice(maxi(from, 0))
	var bytes := _encode_run(run)
	while bytes.size() > TARGET_BYTES and run.size() > 1:
		run = run.slice(maxi(run.size() / 4, 1))
		bytes = _encode_run(run)
	return bytes


static func _encode_run(run: Array[MpInputFrame]) -> PackedByteArray:
	var out := StreamPeerBuffer.new()
	out.big_endian = false
	if run.is_empty():
		return out.data_array
	var first: MpInputFrame = run[0]
	out.put_u8(VERSION)
	out.put_u8(first.strengths.size())
	out.put_u8(run.size())
	out.put_u32(first.seq)
	out.put_double(first.view)
	for i in first.strengths.size():
		out.put_u8(MpInputFrame.quantize_byte(first.strengths[i]))
	for i in first.strengths.size():
		out.put_u32(first.presses[i])
		out.put_u32(first.releases[i])
	_put_values(out, first.values)
	## Each view goes as the change from the one the server rebuilt, so the rounding never adds up.
	var view := first.view
	for k in range(1, run.size()):
		var frame: MpInputFrame = run[k]
		var before: MpInputFrame = run[k - 1]
		var flags := 0
		if frame.strengths != before.strengths:
			flags |= _CHANGED_STRENGTHS
		if frame.presses != before.presses or frame.releases != before.releases:
			flags |= _CHANGED_COUNTERS
		if frame.values != before.values:
			flags |= _CHANGED_VALUES
		out.put_u8(flags)
		var step := clampi(roundi((frame.view - view) * 1000000.0), -2147483647, 2147483647)
		out.put_32(step)
		view += step / 1000000.0
		if flags & _CHANGED_STRENGTHS:
			for i in frame.strengths.size():
				out.put_u8(MpInputFrame.quantize_byte(frame.strengths[i]))
		if flags & _CHANGED_COUNTERS:
			for i in frame.strengths.size():
				out.put_u8(clampi(frame.presses[i] - before.presses[i], 0, 255))
				out.put_u8(clampi(frame.releases[i] - before.releases[i], 0, 255))
		if flags & _CHANGED_VALUES:
			_put_values(out, frame.values)
	return out.data_array


## The frames of a packet for `count` actions, oldest first; empty when anything does not fit.
static func decode(bytes: PackedByteArray, count: int) -> Array[MpInputFrame]:
	var none: Array[MpInputFrame] = []
	if bytes.size() < 15 or bytes.size() > MAX_BYTES:
		return none
	var input := StreamPeerBuffer.new()
	input.big_endian = false
	input.data_array = bytes
	if input.get_u8() != VERSION or input.get_u8() != count:
		return none
	var n := input.get_u8()
	if n < 1 or n > MAX_FRAMES:
		return none
	var frame := MpInputFrame.sized(count)
	frame.seq = input.get_u32()
	frame.view = input.get_double()
	if not _fits(input, count * 9):
		return none
	for i in count:
		frame.strengths[i] = input.get_u8() / 255.0
	for i in count:
		frame.presses[i] = input.get_u32()
		frame.releases[i] = input.get_u32()
	var values: Variant = _get_values(input)
	if values == null:
		return none
	frame.values = values
	if not is_finite(frame.view):
		frame.view = 0.0
	var out: Array[MpInputFrame] = [frame]
	for k in range(1, n):
		if not _fits(input, 5):
			return none
		var flags := input.get_u8()
		var next := frame.next()
		next.view = frame.view + input.get_32() / 1000000.0
		if flags & _CHANGED_STRENGTHS:
			if not _fits(input, count):
				return none
			for i in count:
				next.strengths[i] = input.get_u8() / 255.0
		if flags & _CHANGED_COUNTERS:
			if not _fits(input, count * 2):
				return none
			for i in count:
				next.presses[i] += input.get_u8()
				next.releases[i] += input.get_u8()
		if flags & _CHANGED_VALUES:
			values = _get_values(input)
			if values == null:
				return none
			next.values = values
		out.append(next)
		frame = next
	if input.get_position() != bytes.size():
		return none
	return out


static func _put_values(out: StreamPeerBuffer, values: Dictionary) -> void:
	var data := var_to_bytes(values) if not values.is_empty() else PackedByteArray()
	out.put_u16(data.size())
	out.put_data(data)


## A frame's custom values, or null when they do not fit (not a Dictionary, too many, too big).
static func _get_values(input: StreamPeerBuffer) -> Variant:
	if not _fits(input, 2):
		return null
	var size := input.get_u16()
	if size == 0:
		return {}
	if size > MpInputFrame.MAX_BYTES or not _fits(input, size):
		return null
	var got := input.get_data(size)
	if got[0] != OK:
		return null
	## Never objects: bytes_to_var refuses to decode them.
	var values: Variant = bytes_to_var(got[1])
	if typeof(values) != TYPE_DICTIONARY or (values as Dictionary).size() > MpInputFrame.MAX_VALUES:
		return null
	return values


static func _fits(input: StreamPeerBuffer, bytes: int) -> bool:
	return input.get_available_bytes() >= bytes
